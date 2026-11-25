# Nightly AI re-planner. Runs at night and lets the AI act as the planner: it
# is given the student's CURRENT progress, the REMAINING work, the number of
# days left, and the per-day working hours, and it regenerates the next 7 days'
# study schedule on its own. The result is validated and saved to the database
# (the upcoming milestone_subject_task_items jsonb).
#
# When it runs: only if TODAY has at least one not_started or partially_done
# block (a fully-done day needs no re-plan).
#
# Day budget: 12 hrs/day = 4 blocks of 3 hrs each. A block is a lecture block
# (3 hrs) or a revision block (3 hrs); the AI decides the mix per day.
#
# Fallback: if AI is disabled or returns unusable output, NOTHING is changed and
# the result says the re-plan could not run — the job then emails that failure.
class NightlyReplanService
  PLAN_WINDOW_DAYS  = 7      # re-plan tomorrow .. tomorrow+6
  BLOCKS_PER_DAY    = 4
  HOURS_PER_BLOCK   = 3
  BLOCK_TIMES = [
    [ "09:00", "12:00" ],
    [ "13:00", "16:00" ],
    [ "16:30", "19:30" ],
    [ "20:00", "23:00" ]
  ].freeze
  BLOCK_KINDS = %w[lecture revision mock].freeze

  Result = Struct.new(:changed, :ok, :headline, :moves, :days_touched, keyword_init: true) do
    def changed? = changed
    def ok? = ok
  end

  def initialize(date: Date.current, user: User.current)
    @date      = date
    @user      = user
    @milestone = Milestone.for_date(date)
  end

  def run!
    unless @milestone
      return result(ok: true, changed: false, headline: "No active milestone tonight — nothing to re-plan.")
    end

    today = item_for(@date)
    unless today && incomplete_day?(today)
      return result(ok: true, changed: false, headline: "Today's plan is fully done — no re-plan needed tonight. 🎯")
    end

    unless AiClient.enabled?
      return result(ok: false, changed: false, headline: "AI re-plan could not run tonight: the AI service is not configured.")
    end

    plan = ai_plan or
      return result(ok: false, changed: false, headline: "AI re-plan could not run tonight: the AI did not return a usable plan.")

    days = save_plan!(plan)
    moves = describe(plan)
    result(ok: true, changed: days.any?, days_touched: days, moves: moves,
           headline: days.any? ? "Re-planned the next #{days.size} #{'day'.pluralize(days.size)} around what's left." :
                                 "Nothing left to schedule in the window.")
  rescue => e
    Rails.logger.error("[NightlyReplanService] #{e.class}: #{e.message}")
    result(ok: false, changed: false, headline: "AI re-plan hit an error tonight: #{e.message}")
  end

  private

  # ---- trigger ---------------------------------------------------------------

  def incomplete_day?(item)
    item.studyable_blocks.any? { |b| %w[not_started partially_done].include?(b["status"].to_s) }
  end

  # ---- the window of dates we (re)plan ---------------------------------------

  # Tomorrow .. tomorrow+6, clipped to the milestone's working window
  # (end_date + buffer_time).
  def window_dates
    last = @milestone.end_date + @milestone.buffer_time.to_i
    ((@date + 1)..(@date + PLAN_WINDOW_DAYS)).select { |d| d <= last }
  end

  # ---- AI: build context, ask for a plan, validate it ------------------------

  def ai_plan
    dates = window_dates
    return nil if dates.empty?

    payload = AiClient.new(temperature: 0.4).ask_json(prompt(dates))
    days = Array(payload["days"])
    return nil if days.empty?

    # Map AI's per-date plans by date string; keep only dates in our window.
    allowed = dates.map(&:to_s).to_set
    cleaned = {}
    days.each do |d|
      date = d["date"].to_s
      next unless allowed.include?(date)
      blocks = clean_blocks(d["blocks"])
      cleaned[date] = blocks if blocks.any?
    end
    cleaned.presence
  end

  # Validate / normalise the AI's blocks into our jsonb shape AND enforce the
  # milestone's scope: every block must be one of the milestone's allowed
  # (subject_code, kind) pairs. A block that isn't is snapped to the closest
  # allowed pair (same kind if possible, else the first allowed pair).
  def clean_blocks(raw)
    Array(raw).first(BLOCKS_PER_DAY).each_with_index.map do |b, i|
      b = b.is_a?(Hash) ? b : {}
      code = b["subject_code"].to_s.strip.upcase
      kind = b["kind"].to_s
      kind = nil unless BLOCK_KINDS.include?(kind)

      pair = snap_to_allowed(code, kind)
      start_t, end_t = BLOCK_TIMES[i]
      {
        "block"        => i + 1,
        "start_time"   => start_t,
        "end_time"     => end_t,
        "subject_code" => pair[:code],
        "activity"     => b["activity"].to_s.strip.presence || pair[:label],
        "kind"         => pair[:kind],
        "status"       => "not_started"
      }
    end
  end

  # Milestone scope: the set of (subject_code, kind) pairs this milestone is
  # allowed to schedule, derived from its milestone_subject_tasks. revision_1
  # and revision_2 both map to the "revision" block kind, but we remember the
  # round so the activity label is correct.
  #   => [{ code:, kind:, round:, task_type:, label: }, ...]
  def allowed_pairs
    @allowed_pairs ||= begin
      pairs = @milestone.milestone_subject_tasks.includes(:subject).map do |t|
        kind  = t.task_type == "mock" ? "mock" : (t.task_type == "lecture" ? "lecture" : "revision")
        round = t.task_type == "revision_1" ? 1 : (t.task_type == "revision_2" ? 2 : nil)
        {
          code:      t.subject.code,
          kind:      kind,
          round:     round,
          task_type: t.task_type,
          label:     label_for(t.subject.code, kind, round)
        }
      end
      pairs.presence || [ { code: subject_codes.first, kind: "revision", round: 1,
                            task_type: "revision_1", label: "#{subject_codes.first} revision" } ]
    end
  end

  # Snap an AI (code, kind) to the nearest allowed pair for this milestone:
  # exact match first, then any allowed pair of the same subject, then any
  # allowed pair of the same kind, then the first allowed pair.
  def snap_to_allowed(code, kind)
    allowed_pairs.find { |p| p[:code] == code && p[:kind] == kind } ||
      allowed_pairs.find { |p| p[:code] == code } ||
      allowed_pairs.find { |p| p[:kind] == kind } ||
      allowed_pairs.first
  end

  def label_for(code, kind, round)
    case kind
    when "lecture"  then "#{code} lecture"
    when "mock"     then "#{code} mock test"
    else "#{code} revision R#{round || 1}"
    end
  end

  def prompt(dates)
    <<~PROMPT
      You are the study PLANNER for an Indian CA Final student. Re-plan the next
      #{dates.size} days of study from scratch, based on what is still left to do.

      You are planning WITHIN one milestone: "#{@milestone.name}". A milestone
      covers only a specific set of work — do NOT schedule anything outside it.

      This milestone's ALLOWED blocks are ONLY these (subject_code + kind):
      #{allowed_pairs_lines}
      Every single block you create MUST be one of the pairs listed above. Never
      schedule a subject/kind combination that is not in that list.

      Hard rules:
      - Exactly #{BLOCKS_PER_DAY} blocks per day, each #{HOURS_PER_BLOCK} hours (12 study hours/day).
      - "kind" is one of: "lecture", "revision", "mock" — matching the allowed list.
      - Prioritise the work that is furthest from done, and finish earlier phases
        (lectures) before later ones (revision, mocks) where both are allowed.
      - Don't schedule a pair whose work is already fully done; favour what's left.
      - Plan these exact dates in order: #{dates.map(&:to_s).join(', ')}.

      Days left in this milestone: #{days_left_in_milestone}.
      Total days to exam: #{days_to_exam || 'unknown'}.

      Current progress and remaining work per subject:
      #{progress_lines}

      Return JSON exactly like:
      {
        "days": [
          { "date": "#{dates.first}", "blocks": [
            { "subject_code": "DT", "kind": "lecture", "activity": "DT lecture — Chapter X" },
            { "subject_code": "FR", "kind": "revision", "activity": "FR revision R1 — Ind AS 2" },
            ... (#{BLOCKS_PER_DAY} blocks) ...
          ] },
          ... (one object per date, #{dates.size} total) ...
        ]
      }
      No prose, no code fences.
    PROMPT
  end

  # ---- context the AI sees ---------------------------------------------------

  def subjects
    @subjects ||= @user.subjects.includes(:revision_topics).ordered.to_a
  end

  def subject_codes
    @subject_codes ||= subjects.map(&:code)
  end

  def allowed_pairs_lines
    allowed_pairs.map do |p|
      status = pair_remaining(p)
      "- #{p[:code]} #{p[:kind]}#{p[:round] ? " (round #{p[:round]})" : ''} — #{status}"
    end.join("\n")
  end

  # One-line "what's left" for an allowed pair, so the AI knows how much to plan.
  def pair_remaining(p)
    s = subjects_by_code[p[:code]] or return "subject not found"
    case p[:kind]
    when "lecture"
      "#{s.remaining_lectures.to_i} of #{s.total_lectures.to_i} lectures left"
    when "mock"
      s.mock_status(1) == "done" ? "mock done" : "mock pending"
    else
      done = s.revision_done_count(p[:round] || 1)
      "#{s.revision_topics.size - done} of #{s.revision_topics.size} revision topics left"
    end
  end

  def subjects_by_code
    @subjects_by_code ||= subjects.index_by(&:code)
  end

  def days_left_in_milestone
    [ (@milestone.end_date - @date).to_i, 0 ].max
  end

  def days_to_exam
    last = @user.milestones.maximum(:end_date)
    last ? [ (last - @date).to_i, 0 ].max : nil
  end

  def progress_lines
    subjects.map do |s|
      rev1 = "#{s.revision_done_count(1)}/#{s.revision_topics.size} done"
      rev2 = "#{s.revision_done_count(2)}/#{s.revision_topics.size} done"
      "- #{s.code} (#{s.name}): lectures #{s.lectures_done}/#{s.total_lectures} done " \
        "(#{s.remaining_lectures.to_i} left); revision R1 #{rev1}; R2 #{rev2}; " \
        "mock1 #{s.mock_status(1)}, mock2 #{s.mock_status(2)}"
    end.join("\n")
  end

  # ---- persistence -----------------------------------------------------------

  # Overwrite each planned date's item with the AI's blocks. Returns the dates
  # actually written.
  def save_plan!(plan_by_date)
    plan_by_date.map do |date_str, blocks|
      date = Date.parse(date_str)
      item = @milestone.milestone_subject_task_items.find_or_initialize_by(date: date)
      item.set_schedule!(summary: "AI re-plan (#{@date})", blocks: blocks)
      date
    end.sort
  end

  # ---- summary for the email -------------------------------------------------

  def describe(plan_by_date)
    plan_by_date.sort.map do |date_str, blocks|
      date = Date.parse(date_str)
      counts = blocks.group_by { |b| b["kind"] }.transform_values(&:size)
      parts = counts.map { |k, n| "#{n} #{k}" }.join(", ")
      "#{date.strftime('%a %d %b')}: #{parts}"
    end
  end

  def item_for(date)
    @milestone.milestone_subject_task_items.find_by(date: date)
  end

  def result(ok:, changed:, headline:, moves: [], days_touched: [])
    Result.new(ok: ok, changed: changed, headline: headline, moves: moves, days_touched: days_touched)
  end
end
