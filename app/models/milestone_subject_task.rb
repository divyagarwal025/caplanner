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

  # Coarse status (not_started / in_progress / done) for this slice of work,
  # read from the subject's live progress.
  def status
    case task_type
    when "lecture"    then subject.lecture_status.presence || "not_started"
    when "revision_1" then revision_status(1)
    when "revision_2" then revision_status(2)
    when "mock"       then subject.mock1_status.presence || "not_started"
    else "not_started"
    end
  end

  # Percent complete for progress bars.
  def progress_percent
    case task_type
    when "lecture" then subject.progress_percent
    when "revision_1" then revision_percent(1)
    when "revision_2" then revision_percent(2)
    when "mock" then subject.mock1_status == "done" ? 100 : 0
    else 0
    end
  end

  private

  def revision_topics
    @revision_topics ||= subject.revision_topics.to_a
  end

  def revision_status(round)
    topics = revision_topics
    return "not_started" if topics.empty?
    done = topics.count { |t| t.public_send("rev#{round}_status") == "done" }
    if done == topics.size then "done"
    elsif done.positive? || topics.any? { |t| t.public_send("rev#{round}_status") == "in_progress" } then "in_progress"
    else "not_started"
    end
  end

  def revision_percent(round)
    topics = revision_topics
    return 0 if topics.empty?
    done = topics.count { |t| t.public_send("rev#{round}_status") == "done" }
    (done * 100.0 / topics.size).round
  end

  # Keep user_id in sync with the milestone so the composite FKs are satisfied.
  def inherit_user
    self.user_id ||= milestone&.user_id || subject&.user_id
  end
end
