# A CA Final paper. Lectures are tracked as counters (total / remaining); the
# per-chapter revision work lives in RevisionTopic. Lecture and mock progress
# are coarse status strings (see STATUSES). `code` (e.g. GST, DT, AUDIT) is the
# short key the planner uses.
class Subject < ApplicationRecord
  belongs_to :user
  has_many :revision_topics, dependent: :destroy
  has_many :mock_test_results, dependent: :destroy
  has_many :milestone_subject_tasks, dependent: :destroy

  STATUSES = %w[not_started in_progress done].freeze

  validates :name, :code, presence: true
  validates :code, uniqueness: { scope: :user_id }
  validates :name, uniqueness: { scope: :user_id }
  validates :total_lectures, :remaining_lectures,
            numericality: { greater_than_or_equal_to: 0 }
  validates :lecture_status, :mock1_status, :mock2_status,
            inclusion: { in: STATUSES }, allow_nil: true

  scope :ordered, -> { order(:name) }

  def lectures_done
    [ total_lectures.to_i - remaining_lectures.to_i, 0 ].max
  end

  def progress_percent
    return 0 if total_lectures.to_i.zero?
    ((lectures_done.to_f / total_lectures) * 100).round
  end

  def lectures_complete?
    total_lectures.to_i.positive? && remaining_lectures.to_i.zero?
  end

  # A stable display colour for charts/avatars, derived from the subject code.
  PALETTE = %w[#2563eb #7c3aed #db2777 #ea580c #0d9488 #16a34a #dc2626 #334155].freeze

  def color
    PALETTE[code.to_s.sum % PALETTE.size]
  end

  # ---- revision roll-up (from RevisionTopic rev#{round}_status) --------------

  def revision_status(round)
    topics = revision_topics.to_a
    return "not_started" if topics.empty?
    done = topics.count { |t| t.status_for(round) == "done" }
    if done == topics.size then "done"
    elsif done.positive? || topics.any? { |t| t.status_for(round) == "in_progress" } then "in_progress"
    else "not_started"
    end
  end

  def revision_percent(round)
    topics = revision_topics.to_a
    return 0 if topics.empty?
    done = topics.count { |t| t.status_for(round) == "done" }
    (done * 100.0 / topics.size).round
  end

  def revision_done_count(round)
    revision_topics.count { |t| t.status_for(round) == "done" }
  end

  # ---- mocks ----------------------------------------------------------------

  def mock_status(n)
    (n == 2 ? mock2_status : mock1_status).presence || "not_started"
  end
end
