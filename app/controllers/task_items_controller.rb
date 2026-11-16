class TaskItemsController < ApplicationController
  before_action :set_task, only: %i[update toggle]

  def toggle
    @task.update(done: !@task.done)
    @plan = @task.day_plan
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end

  def update
    @task.update(task_params)
    redirect_back fallback_location: root_path
  end

  private

  def set_task
    @task = TaskItem.find(params[:id])
  end

  def task_params
    params.require(:task_item).permit(:done, :activity, :subject_id, :kind)
  end
end
