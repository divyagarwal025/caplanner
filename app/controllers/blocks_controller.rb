# Set a single block's 3-state status inside a day's task_schedule jsonb. This
# only updates the stored plan — it does NOT roll progress up to subject/topic
# status. Rollup happens when the day is saved (DayPlansController#save).
class BlocksController < ApplicationController
  def update
    date   = Date.parse(params[:date])
    item   = day_item_for(date)
    index  = params[:index].to_i
    status = params[:status].to_s

    item&.set_block_status!(index, status)

    redirect_back fallback_location: root_path
  end
end
