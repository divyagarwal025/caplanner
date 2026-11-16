class SyllabusGoal < ApplicationRecord
  belongs_to :subject

  TASK_TYPES = %w[lecture revision_1 revision_2 mock].freeze
  LABELS = {
    "lecture"    => "Lectures",
    "revision_1" => "Revision 1",
    "revision_2" => "Revision 2",
    "mock"       => "Mock tests"
  }.freeze

  validates :task_type, inclusion: { in: TASK_TYPES }
  validates :units_done, :units_total, numericality: { greater_than_or_equal_to: 0 }

  default_scope { order(:position, :task_type) }
  scope :of_type, ->(t) { where(task_type: t) }

  def label
    LABELS.fetch(task_type, task_type.humanize)
  end

  def remaining
    [ units_total - units_done, 0 ].max
  end

  def percent
    return 0 if units_total.zero?
    (units_done * 100 / units_total)
  end

  def complete?
    units_total.positive? && units_done >= units_total
  end
end
