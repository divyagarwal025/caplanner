class Setting < ApplicationRecord
  DEFAULT_EXAM_DATE = Date.new(2027, 4, 30) # CA Final 2027, Group I day 1.

  validates :email, presence: true

  # Single-row config for this personal planner.
  def self.instance
    first || create!(email: "bhaskar19191@gmail.com", exam_date: DEFAULT_EXAM_DATE)
  end

  def exam_on
    exam_date || DEFAULT_EXAM_DATE
  end

  def days_to_exam(from = Date.current)
    (exam_on - from).to_i
  end
end
