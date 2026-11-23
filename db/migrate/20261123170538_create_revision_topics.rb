class CreateRevisionTopics < ActiveRecord::Migration[8.1]
  def change
    create_table :revision_topics, id: :bigint do |t|
      t.references :subject, null: false, foreign_key: true, type: :bigint, index: false
      t.string :topic_name, null: false
      t.integer :days_required, null: false
      t.integer :order_number, null: false
      t.string :rev1_status
      t.string :rev2_status

      t.index :subject_id
      t.index [ :subject_id, :order_number ]
    end
  end
end
