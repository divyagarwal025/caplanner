# The lecture "remaining" at the moment the plan was seeded. Rollup computes the
# live remaining_lectures as baseline - (lecture blocks marked done), so each
# done block increases the done count idempotently (recompute, not decrement).
class AddBaselineRemainingLecturesToSubjects < ActiveRecord::Migration[8.1]
  def change
    add_column :subjects, :baseline_remaining_lectures, :integer
  end
end
