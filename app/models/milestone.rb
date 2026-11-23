# A dated phase of the preparation (e.g. "Finish lectures", "First revision",
# "Mocks + second revision"). Milestones drive planning: the day plan for a
# date comes from whichever milestone covers it. `buffer_time` is slack days;
# `status` is a coarse state string.
class Milestone < ApplicationRecord
  belongs_to :user
  has_many :milestone_subject_tasks, dependent: :destroy
  has_many :milestone_subject_task_items, dependent: :destroy

  STATUSES = %w[upcoming active done].freeze

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :start_date, :end_date, presence: true
  validates :buffer_time, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }, allow_nil: true
  validate  :end_after_start

  scope :chronological, -> { order(:start_date) }
  scope :covering, ->(date) { where("start_date <= :d AND end_date >= :d", d: date) }

  # The milestone that owns a given date (first match if ranges overlap).
  def self.for_date(date)
    covering(date).chronological.first
  end

  def covers?(date)
    (start_date..end_date).cover?(date)
  end

  def length_in_days
    (end_date - start_date).to_i + 1
  end

  private

  def end_after_start
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, "must be on or after start date") if end_date < start_date
  end
end
