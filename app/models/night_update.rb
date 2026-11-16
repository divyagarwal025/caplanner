class NightUpdate < ApplicationRecord
  validates :date, presence: true, uniqueness: true

  scope :recent, -> { order(date: :desc) }

  def self.for(date)
    find_or_initialize_by(date: date)
  end

  # Pull block counts from the day's plan so the AI sees completion context.
  def sync_from_plan!
    plan = DayPlan.find_by(date: date)
    return unless plan
    self.blocks_done  = plan.blocks_done
    self.blocks_total = plan.blocks_total
    self.done_summary = plan.studyable_tasks.where(done: true).map(&:activity).join("; ")
  end
end
