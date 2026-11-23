# Stage 1 of the milestone-schema migration: drop the legacy domain tables.
# RubyLLM (chats, messages, ruby_llm_*) and active_storage_* are left intact.
# One-way reset — there is no real data to preserve.
class DropLegacyDomainTables < ActiveRecord::Migration[8.1]
  def up
    # Children before parents to stay FK-safe.
    drop_table :task_items, if_exists: true
    drop_table :day_plans, if_exists: true
    drop_table :syllabus_goals, if_exists: true
    drop_table :night_updates, if_exists: true
    drop_table :revision_modules, if_exists: true
    drop_table :productivity_logs, if_exists: true
    drop_table :settings, if_exists: true
    drop_table :subjects, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
