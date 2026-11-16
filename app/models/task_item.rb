class TaskItem < ApplicationRecord
  belongs_to :day_plan
  belongs_to :subject, optional: true
  belongs_to :rescheduled_from, class_name: "TaskItem", optional: true
  has_many :reschedules, class_name: "TaskItem",
           foreign_key: :rescheduled_from_id, dependent: :nullify

  KINDS = %w[lecture revision questions test mock backlog health other].freeze

  validates :activity, presence: true
  validates :kind, inclusion: { in: KINDS }

  scope :ordered, -> { order(:block) }
  scope :studyable, -> { where(kind: %w[lecture revision questions test mock backlog]) }
  scope :pending, -> { where(done: false) }

  before_save :stamp_done_at
  after_update :sync_goal_progress, if: :saved_change_to_done?

  # Map a block's activity to the goal task_type it advances.
  def goal_task_type
    case kind
    when "lecture" then "lecture"
    when "mock"    then "mock"
    when "revision", "questions"
      activity.to_s.match?(/second|rev.?2/i) ? "revision_2" : "revision_1"
    end
  end

  # Planned clock window, e.g. "10:00–13:00".
  def planned_window
    [ start_time, end_time ].compact.join("–").presence
  end

  # True once the planned end time has passed and it still isn't done.
  def overdue?(now = Time.current)
    return false if done? || end_time.blank?
    planned_end_at(now.to_date) < now
  end

  def planned_end_at(date)
    h, m = end_time.split(":").map(&:to_i)
    Time.zone.local(date.year, date.month, date.day, h, m)
  end

  def completed_time_label
    done_at&.in_time_zone&.strftime("%-I:%M %p")
  end

  private

  def stamp_done_at
    if done_changed?
      self.done_at = done? ? Time.current : nil
      self.pending = false if done?
    end
  end

  # Advance (or roll back) the subject's goal for this block's task type when
  # it's ticked/un-ticked, so the roadmap reflects actual completion.
  def sync_goal_progress
    return unless subject && (type = goal_task_type)
    goal = subject.syllabus_goals.find_by(task_type: type)
    return unless goal

    delta = done? ? 1 : -1
    goal.update_column(:units_done, (goal.units_done + delta).clamp(0, goal.units_total))
  end
end
