# Generates EURA's reply off the request thread, persists it (Chat/Message),
# and broadcasts it over Action Cable to the user's coach stream, replacing the
# "typing…" indicator.
class CoachReplyJob < ApplicationJob
  queue_as :default

  def perform(user_id, message)
    user   = User.find(user_id)
    stream = CoachController.stream_name(user)
    convo  = CoachConversation.new(user: user)

    reply = CoachChat.new(user: user).reply(message, history: convo.history(excluding_last_user: true))
    convo.add("assistant", reply)

    # Remove the typing indicator, then append EURA's reply.
    Turbo::StreamsChannel.broadcast_remove_to(stream, target: "coach_typing")
    Turbo::StreamsChannel.broadcast_append_to(
      stream, target: "coach_log",
      partial: "coach/message", locals: { role: "coach", text: reply }
    )
  rescue => e
    Rails.logger.error("[CoachReplyJob] #{e.class}: #{e.message}")
    Turbo::StreamsChannel.broadcast_remove_to(CoachController.stream_name(User.find(user_id)), target: "coach_typing") rescue nil
    raise
  end
end
