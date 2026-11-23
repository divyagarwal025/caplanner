class CreateMilestones < ActiveRecord::Migration[8.1]
  def change
    create_table :milestones, id: :bigint do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint, index: false
      t.string :name, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :buffer_time, null: false, default: 0
      t.string :status

      t.index [ :user_id, :name ], unique: true
      # Composite target for milestone_subject_tasks' (id, user_id) FKs.
      t.index [ :id, :user_id ], unique: true

      t.check_constraint "end_date >= start_date", name: "check_milestone_dates"
    end
  end
end
