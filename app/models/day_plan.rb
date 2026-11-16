class DayPlan < ApplicationRecord
  has_many :task_items, dependent: :destroy
  accepts_nested_attributes_for :task_items

  KINDS = %w[normal sunday festival mcs training].freeze

  validates :date, presence: true, uniqueness: true
  validates :kind, inclusion: { in: KINDS }

  scope :chronological, -> { order(:date) }

  # Find the plan for a date, generating it from the weekly rotation if needed.
  def self.for(date)
    find_by(date: date) || DayPlanGenerator.new(date).generate!
  end

  def studyable_tasks
    task_items.studyable
  end

  def blocks_total
    studyable_tasks.count
  end

  def blocks_done
    studyable_tasks.where(done: true).count
  end

  def complete?
    blocks_total.positive? && blocks_done == blocks_total
  end

  def completion_percent
    return 0 if blocks_total.zero?
    (blocks_done * 100 / blocks_total)
  end

  # Mark every unfinished studyable task as pending (used at end of day
  # and before AI replanning so carried-over work is explicit).
  def mark_pending!
    studyable_tasks.where(done: false).update_all(pending: true)
  end

  def pending_tasks
    studyable_tasks.where(done: false)
  end

  def label
    case kind
    when "festival" then "Festival / family buffer"
    when "mcs"      then "MCS training day"
    when "training" then "Advanced ITT day"
    when "sunday"   then "Sunday — revision & test"
    else "Normal study day"
    end
  end
end
