class CreateMilestoneSubjectTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :milestone_subject_tasks, id: :bigint do |t|
      t.bigint :user_id, null: false
      t.bigint :milestone_id, null: false
      t.bigint :subject_id, null: false
      t.string :task_type, null: false

      t.index [ :milestone_id, :user_id ]
      t.index [ :subject_id, :user_id ]
      t.index [ :milestone_id, :subject_id, :task_type ]
      t.index :user_id
    end

    add_foreign_key :milestone_subject_tasks, :users

    # Composite FKs: the milestone and subject must belong to the same user.
    add_foreign_key :milestone_subject_tasks, :milestones,
                    column: [ :milestone_id, :user_id ],
                    primary_key: [ :id, :user_id ],
                    name: "fk_tasks_milestone_user"

    add_foreign_key :milestone_subject_tasks, :subjects,
                    column: [ :subject_id, :user_id ],
                    primary_key: [ :id, :user_id ],
                    name: "fk_tasks_subject_user"
  end
end
