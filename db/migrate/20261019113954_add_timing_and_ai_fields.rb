class AddTimingAndAiFields < ActiveRecord::Migration[8.1]
  def change
    change_table :task_items, bulk: true do |t|
      # done_at already exists (set when ticked). Add explicit pending marker
      # and a link to the task this one was carried over from, for AI reschedules.
      t.boolean :pending, null: false, default: false
      t.references :rescheduled_from, foreign_key: { to_table: :task_items }
      t.integer :planned_minutes
      t.integer :actual_minutes
    end

    change_table :day_plans, bulk: true do |t|
      t.boolean :ai_generated, null: false, default: false
      t.text :ai_summary
    end
  end
end
