# EURA chatbot endpoint, over Action Cable (Turbo Streams broadcasting).
#
# Flow:
#   1. POST /coach with the student's message.
#   2. Persist the user's turn (Chat/Message), broadcast the user bubble + a
#      "typing…" placeholder to the page's cable stream, and enqueue a job.
#   3. CoachReplyJob generates EURA's AI reply, persists it, and broadcasts it
#      over the same stream, replacing the typing placeholder.
#
# Conversation history lives in the real Chat / Message tables via
# CoachConversation — not a cache.
class CoachController < ApplicationController
  # The per-user Action Cable stream name the chat page subscribes to.
  def self.stream_name(user)
    "coach_#{user.id}"
  end

  def create
    message = params[:message].to_s.strip

    if message.present?
      CoachConversation.new(user: current_user).add("user", message)

      stream = self.class.stream_name(current_user)
      Turbo::StreamsChannel.broadcast_append_to(
        stream, target: "coach_log",
        partial: "coach/message", locals: { role: "user", text: message }
      )
      Turbo::StreamsChannel.broadcast_append_to(
        stream, target: "coach_log", partial: "coach/typing"
      )

      CoachReplyJob.perform_later(current_user.id, message)
    end

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to root_path }
    end
  end

  # Clear the conversation.
  def destroy
    CoachConversation.new(user: current_user).clear
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.update("coach_log", "") }
      format.html { redirect_to root_path }
    end
  end
end
