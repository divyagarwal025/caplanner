class CreateDailyMorningMails < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_morning_mails, id: :bigint do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint, index: false
      t.date :date, null: false
      t.string :status, null: false
      t.text :email_content

      t.index [ :user_id, :date ], unique: true
    end
  end
end
