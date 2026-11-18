# Goal-driven next-day planner. Instead of repeating a fixed weekly rotation,
# it steers toward the exam date: it reads the roadmap (lectures / 2 revisions /
# mocks remaining + days left), folds in last night's progress update (ticks +
# free-text), and asks Groq for tomorrow's best blocks. Falls back to a
# goal-aware rule engine when no API key is configured or the call fails.
class NextDayPlanner
  # Lecture slots 3h, revision slot 2h (kept in sync with DayPlanGenerator).
  BLOCK_TIMES = [ [ "09:00", "12:00" ], [ "13:00", "16:00" ],
                  [ "16:30", "18:30" ], [ "20:00", "23:00" ] ].freeze

  Result = Struct.new(:plan, :source, :error, keyword_init: true)

  def initialize(target_date = Date.current + 1, today: Date.current)
    @target = target_date
    @today  = today
    @road   = RoadmapService.new(today: today)
  end

  def call
    DayPlan.find_by(date: @today)&.mark_pending!
    consume_night_update

    if ai_enabled?
      begin
        return build_from_ai
      rescue => e
        Rails.logger.warn("[NextDayPlanner] AI failed: #{e.class} #{e.message}")
        result = rule_based_plan
        return Result.new(plan: result.plan, source: :fallback, error: e.message)
      end
    end

    rule_based_plan
  end

  private

  def ai_enabled?
    AiClient.enabled?
  end

  def night_update
    @night_update ||= NightUpdate.find_by(date: @today)
  end

  def consume_night_update
    return unless night_update && !night_update.processed?
    night_update.update(processed: true)
  end

  # ---------- AI path ----------

  def build_from_ai
    data = ask_llm
    write_plan(data["summary"], Array(data["blocks"]), ai: true)
  end

  def ask_llm
    AiClient.new(temperature: 0.4).ask_json(prompt)
  end

  def prompt
    <<~PROMPT
      You are the study planner for an Indian CA Final student targeting the
      #{@road.exam_date.strftime('%d %b %Y')} attempt. There are #{@road.days_left}
      days left. Plan the BEST 4-block schedule for #{@target.strftime('%A, %d %B %Y')}
      so the student finishes ALL of this before the exam:
      pending lectures, TWO full revisions of every paper, and mock tests.

      Current phase: #{@road.phase_label}.
      Required pace to finish on time: ~#{@road.required_pace} study-units/day.

      Remaining work (units left) by type:
      #{remaining_lines}

      Per-subject remaining (code: lectures / rev1 / rev2 / mocks left):
      #{subject_matrix}

      Last night's report from the student:
      "#{night_report}"

      Fixed block clock times:
        Block 1: 10:00-13:00   Block 2: 14:00-17:00
        Block 3: 17:45-20:15   Block 4: 21:15-23:45

      Rules:
      - Honour the phase: in "lectures" clear pending lectures first; in
        "revision_1" push first revision; in "mocks + second revision" interleave
        mock tests with second revision.
      - Act on last night's report: carry over anything the student said was left
        or skipped; ease off what they over-did.
      - Prioritise the subjects that are furthest behind (currently: #{@road.focus_subjects.join(', ')}).
      - kind must be one of: lecture, revision, questions, test, backlog, mock.
        Use "mock" for full mock tests, "test" for PYQ/RTP/MTP practice.

      Respond with ONLY valid JSON:
      {
        "summary": "one-sentence rationale tying to the exam goal",
        "blocks": [
          {"start_time":"10:00","end_time":"13:00","subject_code":"GST","activity":"GST lecture","kind":"lecture"}
        ]
      }
    PROMPT
  end

  def remaining_lines
    @road.remaining_by_type.map { |t, n| "  #{SyllabusGoal::LABELS[t]}: #{n}" }.join("\n")
  end

  def subject_matrix
    Subject.all.map do |s|
      g = s.syllabus_goals.index_by(&:task_type)
      "  #{s.code}: #{g['lecture']&.remaining.to_i} / #{g['revision_1']&.remaining.to_i} / " \
      "#{g['revision_2']&.remaining.to_i} / #{g['mock']&.remaining.to_i}"
    end.join("\n")
  end

  def night_report
    return "no report given" unless night_update
    [ night_update.raw_text, night_update.done_summary.present? ? "(completed: #{night_update.done_summary})" : nil ]
      .compact.join(" ").presence || "no report given"
  end

  # ---------- Rule-based fallback ----------
  #
  # Uses the SAME fixed-template, module-aware engine as "today" (DayPlanGenerator)
  # so the fallback plan matches the daily structure the student expects: GST / DT
  # / revision / AUDIT slots, next pending module per slot, skipped work carried
  # over automatically (unfinished goals simply haven't advanced).
  def rule_based_plan
    DayPlan.where(date: @target).destroy_all # rebuild fresh from current goal state
    plan = DayPlanGenerator.new(@target, today: @today).generate!
    plan.update!(
      ai_generated: false,
      ai_summary: "Planned #{@road.phase_label.downcase} — focus #{@road.focus_subjects.join('/')} " \
                  "(#{@road.days_left} days left, ~#{@road.required_pace}/day to finish)."
    )
    Result.new(plan: plan, source: :fallback)
  end

  # ---------- shared writer (AI path) ----------

  def write_plan(summary, blocks, ai:)
    plan = DayPlan.find_or_initialize_by(date: @target)
    plan.kind = @target.sunday? ? "sunday" : "normal"
    plan.ai_generated = ai
    plan.ai_summary = summary
    plan.save!
    plan.task_items.destroy_all

    blocks.each_with_index do |b, i|
      plan.task_items.create!(
        block: i + 1,
        subject: b["subject_code"] && subjects[b["subject_code"]],
        activity: b["activity"].presence || "Revision",
        kind: normalize_kind(b["kind"]),
        start_time: b["start_time"],
        end_time: b["end_time"]
      )
    end
    plan.task_items.create!(block: plan.task_items.count + 1,
                            activity: "Walk + water + 7h sleep", kind: "health")
    Result.new(plan: plan, source: ai ? :ai : :fallback)
  end

  def normalize_kind(kind)
    k = kind.to_s.downcase
    TaskItem::KINDS.include?(k) ? k : "revision"
  end

  def subjects
    @subjects ||= Subject.all.index_by(&:code)
  end
end
