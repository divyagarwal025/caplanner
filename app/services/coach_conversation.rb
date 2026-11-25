# Persistent EURA conversation, stored in the real Chat / Message tables
# (the acts_as_chat scaffold) instead of a cache. Single-user app, so there is
# ONE coach chat; we reuse it and append message rows as the conversation grows.
#
# Message roles follow the acts_as_chat convention: "user" for the student,
# "assistant" for EURA. We write rows directly (we generate replies ourselves
# via CoachChat, not through RubyLLM's completion flow).
class CoachConversation
  MODEL = (ENV["OPENAI_MODEL"].presence || "gpt-4o-mini").freeze
  HISTORY_TURNS = 10 # how many recent turns to feed back as context

  def initialize(user: User.current)
    @user = user
  end

  # The single coach Chat, created on first use (when we actually write).
  def chat
    @chat ||= Chat.order(:id).first || Chat.create!(model: MODEL)
  end

  # The chat if it already exists, without creating one (for read-only views).
  def existing_chat
    @existing_chat ||= Chat.order(:id).first
  end

  # Append a turn. role: "user" | "assistant".
  def add(role, text)
    chat.messages.create!(role: role, content: text.to_s)
  end

  # Recent turns as [{role: "user"|"coach", text:}] for CoachChat's prompt.
  # `excluding_last_user` drops the newest message if it's the user's current
  # turn (already passed to CoachChat separately), so it isn't duplicated.
  def history(excluding_last_user: false)
    rows = chat.messages.order(:id).to_a
    rows.pop if excluding_last_user && rows.last&.role == "user"
    rows.last(HISTORY_TURNS).map do |m|
      { role: m.role == "assistant" ? "coach" : "user", text: m.content.to_s }
    end
  end

  # All turns, oldest first (for rendering the log). Does NOT create a chat.
  def messages
    existing_chat ? existing_chat.messages.order(:id) : Message.none
  end

  # Wipe the conversation.
  def clear
    chat.messages.delete_all
  end
end
