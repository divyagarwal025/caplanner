# EURA reacts when the user marks a block done/partial: generates a short
# motivational line, persists it to the conversation, and broadcasts it to the
# chat over Action Cable.
class CoachReactJob < ApplicationJob
  queue_as :default

  def perform(user_id, status, activity)
    user   = User.find(user_id)
    stream = CoachController.stream_name(user)

    line = CoachChat.new(user: user).react(status: status, activity: activity)
    CoachConversation.new(user: user).add("assistant", line)

    Turbo::StreamsChannel.broadcast_append_to(
      stream, target: "coach_log",
      partial: "coach/message", locals: { role: "coach", text: line }
    )
  rescue => e
    Rails.logger.error("[CoachReactJob] #{e.class}: #{e.message}")
  end
end
