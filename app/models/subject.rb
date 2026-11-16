class Subject < ApplicationRecord
  has_many :task_items, dependent: :nullify
  has_many :syllabus_goals, dependent: :destroy
  has_many :revision_modules, dependent: :destroy

  validates :name, :code, presence: true
  validates :code, uniqueness: true
  validates :lectures_done, :lectures_total,
            numericality: { greater_than_or_equal_to: 0 }

  default_scope { order(:position) }

  def progress_percent
    return 0 if lectures_total.to_i.zero?
    ((lectures_done.to_f / lectures_total) * 100).round
  end

  def remaining
    [ lectures_total.to_i - lectures_done.to_i, 0 ].max
  end
end
