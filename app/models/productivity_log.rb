class ProductivityLog < ApplicationRecord
  validates :date, presence: true, uniqueness: true
  validates :mood, inclusion: { in: 1..5 }, allow_nil: true

  scope :recent, -> { order(date: :desc) }

  # Build (or refresh) a log for a date from that day's task completion.
  def self.capture(date)
    plan = DayPlan.find_by(date: date)
    log  = find_or_initialize_by(date: date)
    if plan
      log.blocks_total = plan.blocks_total
      log.blocks_done  = plan.blocks_done
    end
    log
  end

  def completion_percent
    return 0 if blocks_total.to_i.zero?
    ((blocks_done.to_f / blocks_total) * 100).round
  end

  def health_score
    [ walked, water_ok, sleep_ok ].count(true)
  end
end
