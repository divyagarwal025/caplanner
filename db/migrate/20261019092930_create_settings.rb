class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :email, null: false
      t.integer :morning_hour, null: false, default: 7
      t.integer :evening_hour, null: false, default: 22
      t.string :timezone, null: false, default: "Asia/Kolkata"

      t.timestamps
    end
  end
end
