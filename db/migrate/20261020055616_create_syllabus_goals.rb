class CreateSyllabusGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :syllabus_goals do |t|
      t.references :subject, null: false, foreign_key: true
      t.string :task_type, null: false # lecture | revision_1 | revision_2 | mock
      t.integer :units_total, null: false, default: 0
      t.integer :units_done, null: false, default: 0
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :syllabus_goals, [ :subject_id, :task_type ], unique: true
  end
end
