# The AI "personal guide" layer over JourneyPlanner. It reads the deterministic
# journey plan (phases, milestones, weekly targets, on-track/behind) plus the
# student's recent pace, and returns:
#   - headline: one-line status ("On track" / "3 days behind on lectures")
#   - guidance: 2-4 concrete, prioritised next actions for the week
#   - narrative: a short motivating paragraph tying it to the exam goal
#
# All of it degrades to deterministic copy when AI is off or the call fails, so
# the Roadmap page and emails always have real guidance to show.
class JourneyGuide
  Result = Struct.new(:headline, :guidance, :narrative, :source, keyword_init: true)

  def initialize(today: Date.current)
    @today   = today
    @journey = JourneyPlanner.new(today: today)
    @road    = RoadmapService.new(today: today)
  end

  def call
    return rule_result unless AiClient.enabled?

    begin
      data = AiClient.new(temperature: 0.5).ask_json(prompt)
      Result.new(
        headline:  data["headline"].to_s.presence || rule_headline,
        guidance:  Array(data["guidance"]).map(&:to_s).reject(&:blank?).presence || rule_guidance,
        narrative: data["narrative"].to_s.presence || rule_narrative,
        source:    :ai
      )
    rescue => e
      Rails.logger.warn("[JourneyGuide] AI failed: #{e.class} #{e.message}")
      rule_result
    end
  end

  private

  def rule_result
    Result.new(headline: rule_headline, guidance: rule_guidance, narrative: rule_narrative, source: :rule)
  end

  # ---------- AI prompt ----------

  def prompt
    <<~PROMPT
      You are a personal study coach for an Indian CA Final student aiming for the
      #{@journey.exam_date.strftime('%d %b %Y')} attempt (#{@journey.days_left} days left).

      The goal is to finish, in this order of phases:
        1. all pending lectures
        2. first revision of the whole course (per-subject revision modules)
        3. mock tests + second revision

      The student studies 4 fixed blocks a day: 3 lecture slots + 1 revision slot.

      Deterministic plan computed from remaining work and days left:
      #{plan_summary}

      This week's targets:
      #{weekly_summary}

      Recent pace (last 7 logged days avg completion): #{ProductivityService.week_completion_rate}%.
      Current streak: #{ProductivityService.current_streak} days.

      Give sharp, specific coaching. Return JSON:
      {
        "headline": "one short status line (mention behind/on-track and by how much)",
        "guidance": ["concrete action for this week", "another", "..."],
        "narrative": "2-3 encouraging sentences tying effort to the exam goal"
      }
    PROMPT
  end

  def plan_summary
    @journey.phases.map do |p|
      "  #{p.label}: #{p.units} units, ~#{p.days_needed} days (#{p.start_date.strftime('%d %b')} – #{p.end_date.strftime('%d %b')})"
    end.join("\n") + "\n  Finishes #{@journey.phases.last.end_date.strftime('%d %b %Y')} " \
      "(#{@journey.buffer_days >= 0 ? "#{@journey.buffer_days} days buffer" : "#{-@journey.buffer_days} days OVER"})."
  end

  def weekly_summary
    @journey.weekly_targets[:items].map { |t| "  - #{t[:label]}" }.join("\n").presence || "  (nothing pending)"
  end

  # ---------- deterministic fallback ----------

  def rule_headline
    if @journey.on_track?
      "On track — #{@journey.buffer_days} days of buffer before the exam."
    else
      "Behind by #{-@journey.buffer_days} days — tighten the pace this week."
    end
  end

  def rule_guidance
    @journey.weekly_targets[:items].first(3).map { |t| "Clear #{t[:label]}" }.presence ||
      [ "All targets met — start mock tests and second revision." ]
  end

  def rule_narrative
    "You're in the \"#{@road.phase_label.downcase}\" phase with #{@journey.days_left} days to go. " \
      "Finish #{@road.focus_subjects.join(', ')} first, keep the daily blocks ticking, and the plan stays on course for #{@journey.exam_date.strftime('%d %b')}."
  end
end
