# Milestones overview: each milestone with its name, end date, and the
# per-subject task tracking (lectures / revisions / mocks and their progress).
class MilestonesController < ApplicationController
  def index
    @today      = Date.current
    @milestones = current_user.milestones
                    .includes(milestone_subject_tasks: { subject: :revision_topics })
                    .chronological
  end

  def show
    @milestone = current_user.milestones
                   .includes(milestone_subject_tasks: { subject: :revision_topics })
                   .find(params[:id])
  end
end
