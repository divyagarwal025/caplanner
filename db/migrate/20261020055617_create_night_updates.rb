class CreateNightUpdates < ActiveRecord::Migration[8.1]
  def change
    create_table :night_updates do |t|
      t.date :date, null: false
      t.text :raw_text          # free-text: what was done / what's left
      t.text :done_summary      # derived summary of ticked blocks
      t.integer :blocks_done, null: false, default: 0
      t.integer :blocks_total, null: false, default: 0
      t.boolean :processed, null: false, default: false # consumed by the planner yet?

      t.timestamps
    end
    add_index :night_updates, :date, unique: true
  end
end
