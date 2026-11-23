class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :bigint do |t|
      t.string :email, null: false
      t.string :password, null: false

      t.index :email, unique: true
    end
  end
end
