# Writes the personalised morning letter (and short evening note) for the email
# briefs, in the warm voice of "Eura", the student's preparation guide. The
# morning letter is freshly written by AI each day so no two mornings read the
# same, with a deterministic rotating fallback when AI is off or the call fails,
# so the mailer always has something warm to send.
class BriefWriter
  STUDENT_NAME = "Chhavi".freeze
  GUIDE_NAME   = "Eura".freeze

  # Motivational quotes rotated by date for the fallback letter.
  QUOTES = [
    [ "Success is the sum of small efforts, repeated day in and day out.", "Robert Collier" ],
    [ "It always seems impossible until it's done.", "Nelson Mandela" ],
    [ "The future depends on what you do today.", "Mahatma Gandhi" ],
    [ "Don't watch the clock; do what it does. Keep going.", "Sam Levenson" ],
    [ "Discipline is the bridge between goals and accomplishment.", "Jim Rohn" ],
    [ "Little by little, one travels far.", "J.R.R. Tolkien" ],
    [ "You don't have to be great to start, but you have to start to be great.", "Zig Ziglar" ],
    [ "Energy and persistence conquer all things.", "Benjamin Franklin" ],
    [ "Fall seven times, stand up eight.", "Japanese proverb" ],
    [ "Quality is not an act, it is a habit.", "Aristotle" ]
  ].freeze

  def initialize(road: RoadmapService.new, today: Date.current)
    @road  = road
    @today = today
  end

  # Full morning letter as a hash the mailer template renders:
  #   { greeting:, opening:, blocks: [{icon:, time:, title:, note:}], break_tip:,
  #     quote:, quote_author:, closing:, signoff: }
  # AI-written for daily variety; deterministic rotating fallback otherwise.
  def morning_letter(plan)
    blocks = letter_blocks(plan)
    return fallback_letter(blocks) unless AiClient.enabled?

    ai_letter(plan, blocks) || fallback_letter(blocks)
  rescue => e
    Rails.logger.warn("[BriefWriter] morning_letter AI failed: #{e.class} #{e.message}")
    fallback_letter(blocks)
  end

  # 1–2 reflective sentences for the evening review (unchanged behaviour).
  def evening(percent)
    return evening_fallback(percent) unless AiClient.enabled?

    ai_or_fallback(evening_fallback(percent)) do
      AiClient.new(temperature: 0.7).ask(<<~PROMPT)
        Write a short (max 2 sentences) end-of-day message for an Indian CA Final
        student named #{STUDENT_NAME} who completed #{percent}% of today's study
        blocks. #{@road.days_left} days to the exam. If they did well, celebrate
        briefly; if low, be kind and encourage a reset tomorrow. Warm, plain text.
      PROMPT
    end
  end

  # Kept for backward-compatibility with any caller still using the short intro.
  def morning(plan)
    morning_letter(plan)[:opening]
  end

  private

  # ---- block data (icon + time + title) from the real plan ------------------

  def letter_blocks(plan)
    return [] unless plan

    plan.studyable_tasks.ordered.map do |t|
      {
        icon:  block_icon(t.kind),
        time:  [ fmt(t.start_time), fmt(t.end_time) ].compact.join(" – ").presence || "Anytime today",
        title: t.activity,
        kind:  t.kind
      }
    end
  end

  def block_icon(kind)
    case kind
    when "lecture"  then "📚"
    when "revision" then "☕"
    when "mock"     then "📝"
    else "✨"
    end
  end

  def fmt(hhmm)
    return nil if hhmm.blank?
    t = Time.parse(hhmm)
    t.strftime("%-I:%M %p")
  rescue ArgumentError
    hhmm
  end

  # ---- AI letter ------------------------------------------------------------

  def ai_letter(plan, blocks)
    payload = AiClient.new(temperature: 0.9).ask_json(<<~PROMPT)
      You are "#{GUIDE_NAME}", a warm, loving, slightly playful personal study
      guide for an Indian CA Final student named #{STUDENT_NAME}. Write her
      MORNING motivation email for #{@today.strftime('%A, %d %B %Y')}.

      Context: she is in the "#{@road.phase_label}" phase, #{@road.days_left}
      days from her CA Final exam. Today's focus: #{@road.focus_subjects.join(', ')}.

      Today's blocks (keep the SAME order; write ONE short, specific, encouraging
      line for each, tied to what it is):
      #{blocks.each_with_index.map { |b, i| "#{i + 1}. #{b[:time]} — #{b[:title]}" }.join("\n")}

      Tone: warm, personal, motivating, like a caring mentor who believes in her.
      Address her by name. Make it DIFFERENT from a generic template — fresh
      wording, fresh encouragement. Emojis are welcome but tasteful.

      Return JSON with exactly these keys:
      {
        "greeting": "e.g. Good Morning, #{STUDENT_NAME}! ☀️❤️",
        "opening": "2-3 sentence warm, motivating opening paragraph",
        "block_notes": ["one encouraging line per block, SAME count and order as the list above"],
        "break_tip": "1-2 sentences reminding her to rest/power-nap between tasks and not burn out",
        "quote": "a short motivational quote",
        "quote_author": "the author of the quote",
        "closing": "a stirring 2-4 sentence closing pep paragraph, ending on a hopeful note",
        "signoff": "a short warm sign-off line, e.g. Always cheering for you!"
      }
    PROMPT

    notes = Array(payload["block_notes"])
    blocks_with_notes = blocks.each_with_index.map do |b, i|
      b.merge(note: notes[i].to_s.presence || default_note(b[:kind]))
    end

    {
      greeting:     payload["greeting"].presence || "Good Morning, #{STUDENT_NAME}! ☀️❤️",
      opening:      payload["opening"].presence || fallback_opening,
      blocks:       blocks_with_notes,
      break_tip:    payload["break_tip"].presence || fallback_break_tip,
      quote:        payload["quote"].presence || QUOTES.first[0],
      quote_author: payload["quote_author"].presence || QUOTES.first[1],
      closing:      payload["closing"].presence || fallback_closing,
      signoff:      payload["signoff"].presence || "Always cheering for you!"
    }
  end

  # ---- deterministic fallback letter ---------------------------------------

  def fallback_letter(blocks)
    q = QUOTES[@today.to_s.hash.abs % QUOTES.size]
    {
      greeting:     "Good Morning, #{STUDENT_NAME}! ☀️❤️",
      opening:      fallback_opening,
      blocks:       blocks.map { |b| b.merge(note: default_note(b[:kind])) },
      break_tip:    fallback_break_tip,
      quote:        q[0],
      quote_author: q[1],
      closing:      fallback_closing,
      signoff:      "Always cheering for you!"
    }
  end

  def fallback_opening
    "A new day, a fresh start, and another step closer to becoming a CA. " \
      "You don't need to be perfect today, #{STUDENT_NAME} — you just need to be consistent. " \
      "With #{@road.days_left} days to go, every block you finish is a brick in the future you're building."
  end

  def fallback_break_tip
    "If you finish a task early, don't rush into the next one. Close your eyes, take a short " \
      "power nap, or do something that refreshes you — then return on schedule. This is a marathon, not a sprint."
  end

  def fallback_closing
    "There will be days when concepts feel hard and the syllabus feels endless. On those days, remember why you started. " \
      "Your only competition is yesterday's version of you. One lecture at a time, one revision at a time, one day at a time. " \
      "Now grab your books and give today your absolute best — your CA dream is waiting for you! ❤️"
  end

  def default_note(kind)
    case kind
    when "lecture"  then "Stay attentive and make meaningful notes — every concept you master today is one less worry in the exam."
    when "revision" then "Revise actively: solve questions and flag the areas that need another pass."
    when "mock"     then "Treat it like the real thing — time it, and review every mistake honestly."
    else "Take care of yourself — your health and energy matter as much as your study hours."
    end
  end

  # ---- shared helpers -------------------------------------------------------

  def ai_or_fallback(fallback)
    text = yield
    text.presence || fallback
  rescue => e
    Rails.logger.warn("[BriefWriter] AI failed: #{e.class} #{e.message}")
    fallback
  end

  def evening_fallback(percent)
    if percent >= 70
      "Strong day — #{percent}% of your blocks done, #{STUDENT_NAME}. Rest well and keep the streak alive."
    elsif percent >= 40
      "Solid effort at #{percent}%. Note what slowed you down and carry it into tomorrow's plan."
    else
      "Tough day at #{percent}% — that's okay. Log it honestly and reset; tomorrow is a fresh block."
    end
  end
end
