class AddExamDateToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :exam_date, :date
  end
end
