# EURA — the personal motivator coach chatbot. Answers the student's messages in
# a warm, caring-mentor voice, grounded in her ACTUAL progress (subjects,
# today's blocks, active milestone, days to exam). Uses AiClient (RubyLLM); the
# conversation history is passed in each call so EURA stays in context.
#
# Usage:
#   CoachChat.new(user: current_user).reply(message, history: [{role:, text:}, ...])
class CoachChat
  NAME = "EURA".freeze
  MAX_HISTORY = 8 # last N turns kept for context

  def initialize(user: User.current, date: Date.current)
    @user  = user
    @date  = date
    @today = Milestone.for_date(date)&.milestone_subject_task_items&.find_by(date: date)
  end

  def enabled?
    AiClient.enabled?
  end

  # Returns EURA's reply string. Raises are caught by the caller; on AI-off we
  # return a warm canned line so the UI still works.
  def reply(message, history: [])
    msg = message.to_s.strip
    return "Tell me what's on your mind and I'll cheer you on. 💛" if msg.blank?
    return offline_reply(msg) unless enabled?

    answer = AiClient.new(temperature: 0.8).ask(prompt(msg, history))
    answer.presence || offline_reply(msg)
  rescue => e
    Rails.logger.warn("[CoachChat] #{e.class}: #{e.message}")
    offline_reply(msg)
  end

  # A spontaneous reaction when the user marks a block's status. status is
  # "done" (cheer) or "partially_done" (nudge to push). `activity` is the block
  # label. Returns a short EURA line.
  def react(status:, activity:)
    return react_offline(status) unless enabled?

    answer = AiClient.new(temperature: 0.9).ask(react_prompt(status, activity))
    answer.presence || react_offline(status)
  rescue => e
    Rails.logger.warn("[CoachChat] react failed: #{e.class} #{e.message}")
    react_offline(status)
  end

  private

  # EURA's role is STRICTLY motivation. She does not plan, tutor, or advise on
  # what to study — she warmly redirects those and keeps the student going.
  MOTIVATOR_RULES = <<~RULES.freeze
    YOUR ROLE: You are ONLY a motivator and cheerleader — her emotional support.
    You do NOT make study plans, decide what she should study next, teach or
    explain academic concepts, or change her schedule. If she asks a planning,
    "what should I study", scheduling, or academic/subject-knowledge question,
    do NOT answer it — warmly acknowledge it and gently redirect, e.g. "Your
    plan already has that covered, love — my job is to keep your spirits up! 💛",
    then encourage her. Always stay a warm, uplifting motivator.
  RULES

  def prompt(message, history)
    <<~PROMPT
      You are "#{NAME}", a warm, loving, encouraging personal motivator for an
      Indian CA Final student named #{@user.display_name}. You speak like a caring
      friend who believes in her: supportive, uplifting, a little playful. Keep
      replies SHORT — 1 to 3 sentences. Tasteful emojis welcome. Never invent numbers.

      #{MOTIVATOR_RULES}

      HER CURRENT SITUATION (for empathy only — do NOT turn this into advice)
      #{context_block}

      CONVERSATION SO FAR
      #{history_block(history)}

      She just said: "#{message}"

      Reply as #{NAME}, in the first person, directly to her, as her motivator. Plain text only.
    PROMPT
  end

  def react_prompt(status, activity)
    situation =
      if status == "done"
        %(She just FINISHED this task: "#{activity}". Celebrate her! Cheer with genuine joy and pride.)
      else
        %(She marked this task as PARTIALLY done: "#{activity}". Lovingly encourage her to push a little more and finish it — believe in her.)
      end
    <<~PROMPT
      You are "#{NAME}", #{@user.display_name}'s warm personal motivator.
      #{situation}
      Write ONE short, upbeat, personal line (max 2 sentences). Tasteful emojis
      welcome. First person, directly to her. No advice, no planning — pure
      motivation. Plain text only.
    PROMPT
  end

  def context_block
    lines = []
    lines << "- Today is #{@date.strftime('%A, %d %b %Y')}."
    if (m = Milestone.for_date(@date))
      dl = [ (m.end_date - @date).to_i, 0 ].max
      lines << "- Current phase: \"#{m.name}\" (#{dl} days left in this phase)."
    end
    if (exam = @user.milestones.maximum(:end_date))
      lines << "- Days to the CA Final exam: #{[ (exam - @date).to_i, 0 ].max}."
    end
    if @today
      lines << "- Today's plan: #{@today.blocks_done} of #{@today.blocks_total} blocks done (#{@today.completion_percent}%)."
      @today.studyable_blocks.each do |b|
        lines << "    • #{b['activity']} — #{b['status'].to_s.humanize}"
      end
    else
      lines << "- No study plan is set for today."
    end
    lines << "- Subject progress:"
    @user.subjects.ordered.each do |s|
      lines << "    • #{s.code}: lectures #{s.lectures_done}/#{s.total_lectures} (#{s.progress_percent}%)"
    end
    lines.join("\n")
  end

  def history_block(history)
    turns = Array(history).last(MAX_HISTORY)
    return "(this is the start of your chat)" if turns.empty?
    turns.map do |t|
      who = t[:role].to_s == "coach" ? NAME : @user.display_name
      "#{who}: #{t[:text]}"
    end.join("\n")
  end

  # Warm deterministic reply when AI is unavailable.
  def offline_reply(_message)
    pct = @today&.completion_percent.to_i
    if pct >= 100
      "You've finished everything today — I'm so proud of you. Rest well tonight. 🎉"
    elsif pct.positive?
      "You're already moving — #{pct}% done. Keep going, I'm right here cheering for you. 💪"
    else
      "A fresh start, one step at a time. I believe in you — you've got this. ✨"
    end
  end

  CHEERS = [
    "Yesss! One more done — I'm so proud of you! 🎉",
    "That's the spirit! Another block crushed. 💛",
    "Look at you go — amazing work! 🌟",
    "Done and dusted! You're unstoppable today. 🚀"
  ].freeze
  PUSHES = [
    "So close! Give it a little more push — you've absolutely got this. 💪",
    "Great start on that one! A tiny bit more and it's yours. ✨",
    "You're almost there — don't stop now, I believe in you! 🔥",
    "Halfway is progress! Push through the rest, you can do it. 💛"
  ].freeze

  def react_offline(status)
    pool = status == "done" ? CHEERS : PUSHES
    pool.sample
  end
end
