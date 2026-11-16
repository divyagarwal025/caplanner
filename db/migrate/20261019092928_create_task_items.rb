class CreateTaskItems < ActiveRecord::Migration[8.1]
  def change
    create_table :task_items do |t|
      t.references :day_plan, null: false, foreign_key: true
      t.references :subject, null: true, foreign_key: true
      t.integer :block, null: false, default: 1
      t.string :start_time
      t.string :end_time
      t.string :activity, null: false
      t.string :kind, null: false, default: "lecture"
      t.boolean :done, null: false, default: false
      t.datetime :done_at

      t.timestamps
    end
    add_index :task_items, [ :day_plan_id, :block ]
  end
end
