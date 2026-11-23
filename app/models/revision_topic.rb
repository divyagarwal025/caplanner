# A single chapter/topic of a subject, treated as one revision unit. Each pass
# (first/second revision) has its own status. `days_required` is how long the
# topic should take to revise; `order_number` fixes the sequence within the
# subject. Replaces the old RevisionModule.
class RevisionTopic < ApplicationRecord
  belongs_to :subject

  STATUSES = %w[not_started in_progress done].freeze

  validates :topic_name, presence: true
  validates :days_required, numericality: { greater_than: 0 }
  validates :order_number, numericality: { greater_than_or_equal_to: 0 }
  validates :rev1_status, :rev2_status,
            inclusion: { in: STATUSES }, allow_nil: true

  default_scope { order(:subject_id, :order_number) }

  # Topics still pending for a given revision round (1 or 2).
  scope :for_round, ->(round) { where.not("rev#{round}_status" => "done") }

  def status_for(round)
    round == 1 ? rev1_status : rev2_status
  end

  def done?(round)
    status_for(round) == "done"
  end
end
