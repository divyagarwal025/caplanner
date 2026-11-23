# A recorded mock-test score for a subject. `mock_type` distinguishes the pass
# (e.g. "mock1", "mock2"). Used on the subjects/analytics pages.
class MockTestResult < ApplicationRecord
  belongs_to :subject

  validates :mock_type, presence: true
  validates :marks_obtained, :total_marks,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :recent, -> { order(test_date: :desc) }

  def percent
    return nil if total_marks.to_f.zero? || marks_obtained.nil?
    ((marks_obtained.to_f / total_marks) * 100).round
  end
end
