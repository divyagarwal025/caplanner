# Writes a short, personalised AI message for the morning/evening email briefs,
# tied to the student's real progress and the exam goal. Deterministic fallback
# copy when AI is off or the call fails — the mailer always has something to show.
class BriefWriter
  def initialize(road: RoadmapService.new, today: Date.current)
    @road  = road
    @today = today
  end

  # 1–2 encouraging sentences to open the morning brief.
  def morning(plan)
    return morning_fallback unless AiClient.enabled?

    ai_or_fallback(morning_fallback) do
      AiClient.new(temperature: 0.7).ask(<<~PROMPT)
        Write a short (max 2 sentences) motivating morning message for an Indian
        CA Final student. Phase: #{@road.phase_label}. #{@road.days_left} days to
        the exam. Today's focus subjects: #{@road.focus_subjects.join(', ')}.
        Today's first blocks: #{first_activities(plan)}. Be warm, specific, and
        action-oriented. No emojis, no quotes, plain text.
      PROMPT
    end
  end

  # 1–2 reflective sentences for the evening review.
  def evening(percent)
    return evening_fallback(percent) unless AiClient.enabled?

    ai_or_fallback(evening_fallback(percent)) do
      AiClient.new(temperature: 0.7).ask(<<~PROMPT)
        Write a short (max 2 sentences) end-of-day message for an Indian CA Final
        student who completed #{percent}% of today's study blocks. #{@road.days_left}
        days to the exam. If they did well, celebrate briefly; if low, be kind and
        encourage a reset tomorrow. No emojis, no quotes, plain text.
      PROMPT
    end
  end

  private

  def ai_or_fallback(fallback)
    text = yield
    text.presence || fallback
  rescue => e
    Rails.logger.warn("[BriefWriter] AI failed: #{e.class} #{e.message}")
    fallback
  end

  def first_activities(plan)
    return "rest day" unless plan
    plan.studyable_tasks.first(2).map(&:activity).join(", ").presence || "a light day"
  end

  def morning_fallback
    "You're in the \"#{@road.phase_label.downcase}\" phase with #{@road.days_left} days left — " \
      "focus on #{@road.focus_subjects.join(', ')} and take it one block at a time."
  end

  def evening_fallback(percent)
    if percent >= 70
      "Strong day — #{percent}% of your blocks done. Rest well and keep the streak alive."
    elsif percent >= 40
      "Solid effort at #{percent}%. Note what slowed you down and carry it into tomorrow's plan."
    else
      "Tough day at #{percent}% — that's okay. Log it honestly and reset; tomorrow is a fresh block."
    end
  end
end
