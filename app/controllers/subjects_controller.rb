# Courses: per-subject tracking of every work stream —
# Lectures, Revision 1, Revision 2, Mock 1 and Mock 2.
class SubjectsController < ApplicationController
  def index
    @subjects = current_user.subjects.includes(:revision_topics).ordered
  end
end
