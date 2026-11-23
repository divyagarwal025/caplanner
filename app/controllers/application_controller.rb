class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user

  private

  # Single-user app: the one and only account.
  def current_user
    @current_user ||= User.current
  end

  # The day plan (jsonb blocks) for a date = the item on the milestone covering
  # that date. Returns nil when no milestone covers the date or it has no item.
  def day_item_for(date)
    milestone = Milestone.for_date(date)
    milestone&.milestone_subject_task_items&.find_by(date: date)
  end
end
