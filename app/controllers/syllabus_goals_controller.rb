class SyllabusGoalsController < ApplicationController
  def update
    @goal = SyllabusGoal.find(params[:id])
    @goal.update(goal_params)
    redirect_to roadmap_path, notice: "#{@goal.subject.code} #{@goal.label} updated."
  end

  private

  def goal_params
    params.require(:syllabus_goal).permit(:units_done, :units_total)
  end
end
