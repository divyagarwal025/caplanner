# Writes the personalised morning letter for the email brief, in the warm voice
# of a caring study guide. The letter is freshly written by AI each day (so no
# two mornings read the same), with a deterministic rotating fallback when AI is
# off or the call fails — so the mailer always has something warm to send.
#
# New-schema aware: it reads today's MilestoneSubjectTaskItem (jsonb blocks) and
# the active Milestone for phase / days-left context.
class BriefWriter
  GUIDE_NAME = "Eura".freeze

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

  def initialize(today: Date.current, user: User.current)
    @today     = today
    @user      = user
    @name      = user.display_name
    @milestone = Milestone.for_date(today)
    @item      = @milestone&.milestone_subject_task_items&.find_by(date: today)
  end

  # Full morning letter the mailer template renders:
  #   { greeting:, opening:, blocks: [{icon:, time:, title:, note:}], break_tip:,
  #     quote:, quote_author:, closing:, signoff: }
  def morning_letter
    blocks = letter_blocks
    return fallback_letter(blocks) unless AiClient.enabled?

    ai_letter(blocks) || fallback_letter(blocks)
  rescue => e
    Rails.logger.warn("[BriefWriter] morning_letter AI failed: #{e.class} #{e.message}")
    fallback_letter(blocks)
  end

  private

  # ---- context --------------------------------------------------------------

  def days_left
    return nil unless @milestone
    # days to the exam = last milestone's end date for this user.
    exam_end = @user.milestones.maximum(:end_date)
    exam_end ? [ (exam_end - @today).to_i, 0 ].max : nil
  end

  def phase_label
    @milestone&.name || "Preparation"
  end

  def focus_subjects
    return [] unless @milestone
    @milestone.milestone_subject_tasks.includes(:subject).map { |t| t.subject.code }.uniq
  end

  # ---- block data from today's jsonb schedule -------------------------------

  def letter_blocks
    return [] unless @item

    @item.blocks.map do |b|
      {
        icon:  block_icon(b["kind"]),
        time:  [ b["start_time"], b["end_time"] ].compact.join(" – ").presence || "Anytime today",
        title: b["activity"].to_s,
        kind:  b["kind"].to_s
      }
    end
  end

  def block_icon(kind)
    case kind
    when "lecture"            then "📚"
    when "revision"           then "☕"
    when "questions"          then "✍️"
    when "mock", "test"       then "📝"
    else "✨"
    end
  end

  # ---- AI letter ------------------------------------------------------------

  def ai_letter(blocks)
    payload = AiClient.new(temperature: 0.9).ask_json(<<~PROMPT)
      You are "#{GUIDE_NAME}", a warm, loving, slightly playful personal study
      guide for an Indian CA Final student named #{@name}. Write her MORNING
      motivation email for #{@today.strftime('%A, %d %B %Y')}.

      Context: she is in the "#{phase_label}" phase#{days_left ? ", #{days_left} days from her CA Final exam" : ''}.
      Today's focus: #{focus_subjects.join(', ').presence || 'her plan'}.

      Today's blocks (keep the SAME order; write ONE short, specific, encouraging
      line for each, tied to what it is):
      #{blocks.each_with_index.map { |b, i| "#{i + 1}. #{b[:time]} — #{b[:title]}" }.join("\n").presence || '(no blocks scheduled today)'}

      Tone: warm, personal, motivating, like a caring mentor who believes in her.
      Address her by name. Make it fresh — not a generic template. Tasteful emojis welcome.

      Return JSON with exactly these keys:
      {
        "greeting": "e.g. Good Morning, #{@name}! ☀️❤️",
        "opening": "2-3 sentence warm, motivating opening paragraph",
        "block_notes": ["one encouraging line per block, SAME count and order as the list above"],
        "break_tip": "1-2 sentences reminding her to rest between tasks and not burn out",
        "quote": "a short motivational quote",
        "quote_author": "the author of the quote",
        "closing": "a stirring 2-4 sentence closing pep paragraph ending on a hopeful note",
        "signoff": "a short warm sign-off, e.g. Always cheering for you!"
      }
    PROMPT

    notes = Array(payload["block_notes"])
    blocks_with_notes = blocks.each_with_index.map do |b, i|
      b.merge(note: notes[i].to_s.presence || default_note(b[:kind]))
    end

    {
      greeting:     payload["greeting"].presence || "Good Morning, #{@name}! ☀️❤️",
      opening:      payload["opening"].presence || fallback_opening,
      blocks:       blocks_with_notes,
      break_tip:    payload["break_tip"].presence || fallback_break_tip,
      quote:        payload["quote"].presence || QUOTES.first[0],
      quote_author: payload["quote_author"].presence || QUOTES.first[1],
      closing:      payload["closing"].presence || fallback_closing,
      signoff:      payload["signoff"].presence || "Always cheering for you!"
    }
  end

  # ---- deterministic fallback ----------------------------------------------

  def fallback_letter(blocks)
    q = QUOTES[@today.to_s.hash.abs % QUOTES.size]
    {
      greeting:     "Good Morning, #{@name}! ☀️❤️",
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
    dl = days_left ? "With #{days_left} days to go, every" : "Every"
    "A new day, a fresh start, and another step closer to becoming a CA. " \
      "You don't need to be perfect today, #{@name} — you just need to be consistent. " \
      "#{dl} block you finish is a brick in the future you're building."
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
    when "lecture"            then "Stay attentive and make meaningful notes — every concept you master today is one less worry in the exam."
    when "revision"           then "Revise actively: solve questions and flag the areas that need another pass."
    when "questions"          then "Work problems with a timer — speed and accuracy both grow with practice."
    when "mock", "test"       then "Treat it like the real thing — time it, and review every mistake honestly."
    else "Take care of yourself — your health and energy matter as much as your study hours."
    end
  end
end
