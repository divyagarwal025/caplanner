class CreateRevisionModules < ActiveRecord::Migration[8.1]
  def change
    create_table :revision_modules do |t|
      t.references :subject, null: false, foreign_key: true
      t.integer :chapter_no, null: false
      t.string  :name, null: false
      t.integer :expected_days, null: false, default: 3
      t.integer :position, null: false, default: 0
      # Revision progress for this chapter (false until revised).
      t.boolean :revision_1_done, null: false, default: false
      t.boolean :revision_2_done, null: false, default: false

      t.timestamps
    end

    add_index :revision_modules, [ :subject_id, :chapter_no ], unique: true
  end
end
