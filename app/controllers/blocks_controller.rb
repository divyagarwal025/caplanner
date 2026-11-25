# Auto-save a single block's 3-state status (dashboard, today only), roll
# progress up, and respond over AJAX (Turbo Stream) so the dashboard updates
# in place without a full page reload. Editing is allowed ONLY for today.
class BlocksController < ApplicationController
  def update
    date = Date.parse(params[:date])

    unless date == Date.current
      return respond_to do |format|
        format.turbo_stream { head :forbidden }
        format.html { redirect_to root_path, alert: "You can only update today's blocks." }
      end
    end

    status = params[:status].to_s
    index  = params[:index].to_i
    @today = day_item_for(date)
    if @today
      @today.set_block_status!(index, status)
      ProgressRollup.new(@today).apply!

      # EURA reacts in the chat: cheer on "done", nudge on "partially_done".
      if %w[done partially_done].include?(status)
        activity = @today.blocks[index]&.dig("activity").to_s
        CoachReactJob.perform_later(current_user.id, status, activity)
      end
    end
    @subjects = current_user.subjects.ordered

    respond_to do |format|
      format.turbo_stream   # app/views/blocks/update.turbo_stream.erb
      format.html { redirect_to root_path }
    end
  end
end
