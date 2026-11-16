class CreateProductivityLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :productivity_logs do |t|
      t.date :date, null: false
      t.integer :blocks_done, null: false, default: 0
      t.integer :blocks_total, null: false, default: 0
      t.boolean :walked, null: false, default: false
      t.boolean :water_ok, null: false, default: false
      t.boolean :sleep_ok, null: false, default: false
      t.integer :mood
      t.text :notes

      t.timestamps
    end
    add_index :productivity_logs, :date, unique: true
  end
end
