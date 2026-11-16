# A single CA Final chapter, treated as one revision module. Each subject has a
# fixed list of these (from the ICAI syllabus). `expected_days` is how long the
# chapter should take to revise (2-5). The journey planner sizes the revision
# phases from these durations rather than a flat module count.
class RevisionModule < ApplicationRecord
  belongs_to :subject

  validates :chapter_no, :name, presence: true
  validates :expected_days, numericality: { greater_than: 0 }
  validates :chapter_no, uniqueness: { scope: :subject_id }

  default_scope { order(:subject_id, :chapter_no) }
  scope :for_revision, ->(round) { where("revision_#{round}_done" => false) }

  def done?(round)
    round == 1 ? revision_1_done : revision_2_done
  end
end
