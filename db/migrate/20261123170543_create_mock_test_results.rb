class CreateMockTestResults < ActiveRecord::Migration[8.1]
  def change
    create_table :mock_test_results, id: :bigint do |t|
      t.references :subject, null: false, foreign_key: true, type: :bigint, index: false
      t.string :mock_type, null: false
      t.decimal :marks_obtained, precision: 8, scale: 2
      t.decimal :total_marks, precision: 8, scale: 2
      t.date :test_date

      t.index :subject_id
      t.index [ :subject_id, :mock_type ]
    end
  end
end
