class CreateDayPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :day_plans do |t|
      t.date :date, null: false
      t.string :kind, null: false, default: "normal"
      t.string :note
      t.boolean :planned, null: false, default: false

      t.timestamps
    end
    add_index :day_plans, :date, unique: true
  end
end
