class SubjectsController < ApplicationController
  def index
    @subjects = Subject.all
  end

  def update
    @subject = Subject.find(params[:id])
    @subject.update(subject_params)
    redirect_to subjects_path, notice: "#{@subject.code} updated."
  end

  private

  def subject_params
    params.require(:subject).permit(:lectures_done, :lectures_total)
  end
end
