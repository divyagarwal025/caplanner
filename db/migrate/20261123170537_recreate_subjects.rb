class RecreateSubjects < ActiveRecord::Migration[8.1]
  def change
    create_table :subjects, id: :bigint do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint, index: false
      t.string :name, null: false
      t.string :code, null: false
      t.integer :total_lectures, null: false, default: 0
      t.integer :remaining_lectures, null: false, default: 0
      t.string :lecture_status
      t.string :mock1_status
      t.string :mock2_status

      t.index [ :user_id, :name ], unique: true
      t.index [ :user_id, :code ], unique: true
      # Composite target for milestone_subject_tasks' (id, user_id) FKs.
      t.index [ :id, :user_id ], unique: true
    end
  end
end
