# The single account this personal planner belongs to. No auth UI — the app is
# single-user, so everything is scoped to `User.sole`. The `password` column is
# a plain string per the schema (no digest); do not treat it as secure.
class User < ApplicationRecord
  has_many :subjects, dependent: :destroy
  has_many :milestones, dependent: :destroy
  has_many :daily_morning_mails, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :password, presence: true

  # The one-and-only user. Raises if there are zero or more than one, which is
  # exactly the invariant we want for a single-user app.
  def self.current
    sole
  end
end
