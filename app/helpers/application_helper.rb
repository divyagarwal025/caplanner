module ApplicationHelper
  MOTIVATIONAL_QUOTES = [
    [ "The expert in anything was once a beginner.", "Helen Hayes" ],
    [ "Success is the sum of small efforts, repeated day in and day out.", "Robert Collier" ],
    [ "Don't watch the clock; do what it does. Keep going.", "Sam Levenson" ],
    [ "It always seems impossible until it's done.", "Nelson Mandela" ],
    [ "The secret of getting ahead is getting started.", "Mark Twain" ],
    [ "Discipline is choosing between what you want now and what you want most.", "Abraham Lincoln" ],
    [ "Little by little, one travels far.", "J.R.R. Tolkien" ],
    [ "You don't have to be great to start, but you have to start to be great.", "Zig Ziglar" ],
    [ "Hard work beats talent when talent doesn't work hard.", "Tim Notke" ],
    [ "A year from now you may wish you had started today.", "Karen Lamb" ],
    [ "Fall seven times, stand up eight.", "Japanese Proverb" ],
    [ "Your future is created by what you do today, not tomorrow.", "Robert Kiyosaki" ]
  ].freeze

  # A motivational quote for the dashboard hero. Stable for a given day (so it
  # doesn't flicker on every reload) but rotates day to day.
  def motivational_quote(seed = Date.current.to_s)
    MOTIVATIONAL_QUOTES[seed.hash.abs % MOTIVATIONAL_QUOTES.size]
  end

  KIND_COLORS = {
    "lecture"   => "#2563eb",
    "revision"  => "#7c3aed",
    "questions" => "#db2777",
    "test"      => "#ea580c",
    "mock"      => "#dc2626",
    "backlog"   => "#64748b",
    "health"    => "#16a34a",
    "other"     => "#334155"
  }.freeze

  def kind_color(kind)
    KIND_COLORS.fetch(kind, "#334155")
  end

  # Colour for a subject code (nil-safe); used by the block list.
  def subject_color(code)
    return nil if code.blank?
    (@subject_colors ||= Subject.all.index_by(&:code))[code]&.color
  end

  # --- motivational coach (girl under the progress ring) ---------------------
  #
  # The dashboard's personal motivator coach. She has a name — EURA — and speaks
  # in the same warm, caring mentor voice as the morning-brief guide
  # (BriefWriter::GUIDE_NAME). Her message changes with today's completion %.
  #
  # Returns { coach:, image:, title:, message:, mood: } chosen from today's %.
  # Images live in app/assets/images/ — provide these three files:
  #   coach-celebrate.png  coach-push.png  coach-start.png
  COACH_NAME = "EURA".freeze

  # Each line is written as EURA speaking directly to the student.
  COACH_CELEBRATE = [
    "You did it — every single block, done. I'm so proud of you today. 🎉",
    "A perfect day. This is exactly how rank-holders are made, and you just proved it.",
    "100%! Close the books and rest proud tonight — you earned every bit of it. ❤️"
  ].freeze
  COACH_PUSH = [
    "Beautiful momentum! Just a little more and today is a clean sweep — I believe in you. 💪",
    "You're already past the hard part. Finish strong, I'm right here cheering you on.",
    "Keep going — the last few blocks are where champions are made. You've got this."
  ].freeze
  COACH_START = [
    "Good to see you! Let's start gentle — just open the first block, and I'll be with you. ✨",
    "The hardest part is beginning. Tick one task, and the rest will follow. You can do this.",
    "A fresh day, a fresh start. Future-you is counting on today — shall we begin? 🚀"
  ].freeze

  # Each mood's headline, in EURA's voice.
  COACH_TITLES = {
    "celebrate" => "EURA is so proud! 🎉",
    "push"      => "EURA says: keep pushing! 💪",
    "start"     => "EURA is here for you ✨"
  }.freeze

  # Time-of-day greeting for EURA's welcome message.
  def coach_greeting(now = Time.current)
    h = now.hour
    if h < 12 then "Good morning!"
    elsif h < 17 then "Good afternoon!"
    else "Good evening!"
    end
  end

  # pct: today's completion percent (0–100). seed keeps the line stable per render.
  def coach_for(pct, seed = Date.current.to_s)
    pct  = pct.to_i
    mood =
      if pct >= 100 then "celebrate"
      elsif pct.positive? then "push"
      else "start"
      end
    lines = { "celebrate" => COACH_CELEBRATE, "push" => COACH_PUSH, "start" => COACH_START }[mood]

    {
      coach:   COACH_NAME,
      image:   "coach-#{mood}.png",
      title:   COACH_TITLES[mood],
      message: lines[seed.hash.abs % lines.size],
      mood:    mood
    }
  end

  # --- 3-state block status helpers ------------------------------------------

  STATUS_LABELS = {
    "not_started"    => "○ Not started",
    "partially_done" => "◐ Partial",
    "done"           => "✓ Done"
  }.freeze

  STATUS_PILL = {
    "not_started"    => "soft-blue",
    "partially_done" => "soft-amber",
    "done"           => "soft-teal"
  }.freeze

  def status_label(status)
    STATUS_LABELS.fetch(status.to_s, STATUS_LABELS["not_started"])
  end

  def status_pill_class(status)
    STATUS_PILL.fetch(status.to_s, "soft-blue")
  end

  # Small square swatch colour for a block's status, used by the calendar's
  # read-only block dots. Future days always render as "not started".
  STATUS_DOT = {
    "done"           => "#14b8a6", # teal
    "partially_done" => "#f59e0b", # amber
    "not_started"    => "#cbd5e1"  # grey
  }.freeze

  # The status to DISPLAY for a block on a given calendar date. Past & today use
  # the stored status; tomorrow and later are always shown as not_started.
  def calendar_block_status(block, date)
    return "not_started" if date > Date.current
    STATUSES_FALLBACK.include?(block["status"].to_s) ? block["status"].to_s : "not_started"
  end

  STATUSES_FALLBACK = %w[not_started partially_done done].freeze

  def status_dot_color(status)
    STATUS_DOT.fetch(status.to_s, "#cbd5e1")
  end

  # Green→amber→grey scale for a completion percentage (calendar cells, rings).
  def completion_color(percent)
    case percent
    when 0 then "#e2e8f0"
    when 1..39 then "#f97316"
    when 40..69 then "#eab308"
    when 70..89 then "#65a30d"
    else "#16a34a"
    end
  end

  # SVG conic-style progress ring.
  def progress_ring(percent, size: 92, stroke: 9, color: nil)
    color ||= completion_color(percent)
    r = (size - stroke) / 2.0
    circ = 2 * Math::PI * r
    offset = circ * (1 - percent / 100.0)
    content_tag :svg, width: size, height: size, viewBox: "0 0 #{size} #{size}", class: "ring" do
      concat tag.circle(cx: size / 2, cy: size / 2, r: r, fill: "none", stroke: "#e2e8f0", "stroke-width": stroke)
      concat tag.circle(cx: size / 2, cy: size / 2, r: r, fill: "none", stroke: color,
                        "stroke-width": stroke, "stroke-dasharray": circ.round(1),
                        "stroke-dashoffset": offset.round(1), "stroke-linecap": "round",
                        transform: "rotate(-90 #{size / 2} #{size / 2})")
      concat content_tag(:text, "#{percent}%", x: "50%", y: "50%", "text-anchor": "middle",
                         "dominant-baseline": "central", class: "ring-label")
    end
  end
end
