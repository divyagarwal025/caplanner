class CreateMilestoneSubjectTaskItems < ActiveRecord::Migration[8.1]
  def change
    create_table :milestone_subject_task_items, id: :bigint do |t|
      t.references :milestone, null: false, foreign_key: true, type: :bigint, index: false
      t.date :date, null: false
      t.jsonb :task_schedule, null: false, default: {}
      t.text :ai_summary_night_update
      t.jsonb :updated_task_schedule
      t.text :todays_productivity

      t.index [ :milestone_id, :date ], unique: true
    end
  end
end
