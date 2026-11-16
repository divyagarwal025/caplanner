# Uses AI to turn a student's free-text night report into structured signals,
# then applies them: adjusts today's task completion and surfaces carry-overs
# so the next-day planner acts on real intent (not just keyword matching).
#
# Example input: "Finished GST ch 1-3, FR revision half done, skipped Audit —
# too tired. Push Audit tomorrow."
#
# Falls back to a no-op (leaving raw_text for the rule planner) when AI is off
# or the call fails.
class NightUpdateInterpreter
  Result = Struct.new(:applied, :summary, :carry_over, :source, :error, keyword_init: true)

  def initialize(night_update)
    @night = night_update
    @date  = night_update.date
  end

  def call
    return rule_result unless AiClient.enabled? && @night.raw_text.present?

    begin
      data = AiClient.new(temperature: 0.2).ask_json(prompt)
      apply!(data)
      Result.new(
        applied: true,
        summary: data["summary"].to_s,
        carry_over: Array(data["carry_over"]),
        source: :ai
      )
    rescue => e
      Rails.logger.warn("[NightUpdateInterpreter] AI failed: #{e.class} #{e.message}")
      rule_result(error: e.message)
    end
  end

  private

  def rule_result(error: nil)
    Result.new(applied: false, summary: @night.raw_text.to_s, carry_over: [], source: :rule, error: error)
  end

  # Mark matching subjects' tasks done/undone based on the parsed report.
  def apply!(data)
    plan = DayPlan.find_by(date: @date)
    return unless plan

    done_codes = Array(data["completed_subject_codes"]).map { |c| c.to_s.upcase }
    return if done_codes.empty?

    plan.studyable_tasks.includes(:subject).find_each do |task|
      next unless task.subject && done_codes.include?(task.subject.code)
      task.update!(done: true) unless task.done? # triggers goal sync
    end
  end

  def prompt
    <<~PROMPT
      You are parsing an Indian CA Final student's end-of-day study report.
      Today is #{@date.strftime('%A, %d %b %Y')}.

      The valid subject codes are: #{Subject.pluck(:code).join(', ')}.

      Today's planned blocks were:
      #{planned_blocks}

      The student's free-text report:
      "#{@night.raw_text}"

      Extract what actually happened. Only use the subject codes listed above.
      Return JSON with:
      {
        "summary": "one short sentence summarising the day",
        "completed_subject_codes": ["CODE", ...],   // subjects whose block was fully finished
        "partial_subject_codes": ["CODE", ...],     // started but not finished
        "carry_over": ["short note of what to push to tomorrow", ...]
      }
    PROMPT
  end

  def planned_blocks
    plan = DayPlan.find_by(date: @date)
    return "  (no plan found)" unless plan
    plan.studyable_tasks.map { |t| "  - #{t.subject&.code || '—'}: #{t.activity}" }.join("\n")
  end
end
