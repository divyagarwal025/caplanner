# A record of the morning brief sent (or queued) for a given date. Stores the
# rendered email so it can be re-displayed, and a status for delivery tracking.
class DailyMorningMail < ApplicationRecord
  belongs_to :user

  STATUSES = %w[pending sent failed].freeze

  validates :date, presence: true, uniqueness: { scope: :user_id }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent, -> { order(date: :desc) }

  def self.for(user, date)
    find_or_initialize_by(user: user, date: date) do |m|
      m.status ||= "pending"
    end
  end
end
