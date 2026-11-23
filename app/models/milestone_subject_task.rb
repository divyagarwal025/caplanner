# Join row: which subject contributes which kind of work to a milestone. Lets a
# milestone scope "GST lectures + FR revision_1", etc. Composite FKs at the DB
# level guarantee the milestone and subject belong to the same user.
class MilestoneSubjectTask < ApplicationRecord
  belongs_to :user
  belongs_to :milestone
  belongs_to :subject

  TASK_TYPES = %w[lecture revision_1 revision_2 mock].freeze
  LABELS = {
    "lecture"    => "Lectures",
    "revision_1" => "Revision 1",
    "revision_2" => "Revision 2",
    "mock"       => "Mock tests"
  }.freeze

  validates :task_type, inclusion: { in: TASK_TYPES }
  validates :subject_id, uniqueness: { scope: [ :milestone_id, :task_type ] }

  before_validation :inherit_user, on: :create

  def label
    LABELS.fetch(task_type, task_type.humanize)
  end

  private

  # Keep user_id in sync with the milestone so the composite FKs are satisfied.
  def inherit_user
    self.user_id ||= milestone&.user_id || subject&.user_id
  end
end
