class CreateSubjects < ActiveRecord::Migration[8.1]
  def change
    create_table :subjects do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.integer :lectures_total, null: false, default: 0
      t.integer :lectures_done, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.string :color, null: false, default: "#64748b"

      t.timestamps
    end
    add_index :subjects, :code, unique: true
  end
end
