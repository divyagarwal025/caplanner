# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_23_180000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "chats", force: :cascade do |t|
    t.boolean "cancelled", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "ruby_llm_model_id", null: false
    t.datetime "updated_at", null: false
    t.index ["ruby_llm_model_id"], name: "index_chats_on_ruby_llm_model_id"
  end

  create_table "daily_morning_mails", force: :cascade do |t|
    t.date "date", null: false
    t.text "email_content"
    t.string "status", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "date"], name: "index_daily_morning_mails_on_user_id_and_date", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.string "cache_ttl"
    t.boolean "cache_until_here", default: false, null: false
    t.bigint "chat_id", null: false
    t.jsonb "citations"
    t.text "content"
    t.datetime "created_at", null: false
    t.string "finish_reason"
    t.jsonb "raw_content"
    t.jsonb "raw_reasoning"
    t.string "role", null: false
    t.jsonb "server_tool_calls"
    t.text "thinking_signature"
    t.text "thinking_text"
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
  end

  create_table "milestone_subject_task_items", force: :cascade do |t|
    t.text "ai_summary_night_update"
    t.date "date", null: false
    t.bigint "milestone_id", null: false
    t.jsonb "task_schedule", default: {}, null: false
    t.text "todays_productivity"
    t.jsonb "updated_task_schedule"
    t.index ["milestone_id", "date"], name: "index_milestone_subject_task_items_on_milestone_id_and_date", unique: true
  end

  create_table "milestone_subject_tasks", force: :cascade do |t|
    t.bigint "milestone_id", null: false
    t.bigint "subject_id", null: false
    t.string "task_type", null: false
    t.bigint "user_id", null: false
    t.index ["milestone_id", "subject_id", "task_type"], name: "idx_on_milestone_id_subject_id_task_type_374452faad"
    t.index ["milestone_id", "user_id"], name: "index_milestone_subject_tasks_on_milestone_id_and_user_id"
    t.index ["subject_id", "user_id"], name: "index_milestone_subject_tasks_on_subject_id_and_user_id"
    t.index ["user_id"], name: "index_milestone_subject_tasks_on_user_id"
  end

  create_table "milestones", force: :cascade do |t|
    t.integer "buffer_time", default: 0, null: false
    t.date "end_date", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.string "status"
    t.bigint "user_id", null: false
    t.index ["id", "user_id"], name: "index_milestones_on_id_and_user_id", unique: true
    t.index ["user_id", "name"], name: "index_milestones_on_user_id_and_name", unique: true
    t.check_constraint "end_date >= start_date", name: "check_milestone_dates"
  end

  create_table "mock_test_results", force: :cascade do |t|
    t.decimal "marks_obtained", precision: 8, scale: 2
    t.string "mock_type", null: false
    t.bigint "subject_id", null: false
    t.date "test_date"
    t.decimal "total_marks", precision: 8, scale: 2
    t.index ["subject_id", "mock_type"], name: "index_mock_test_results_on_subject_id_and_mock_type"
    t.index ["subject_id"], name: "index_mock_test_results_on_subject_id"
  end

  create_table "revision_topics", force: :cascade do |t|
    t.integer "days_required", null: false
    t.integer "order_number", null: false
    t.string "rev1_status"
    t.string "rev2_status"
    t.bigint "subject_id", null: false
    t.string "topic_name", null: false
    t.index ["subject_id", "order_number"], name: "index_revision_topics_on_subject_id_and_order_number"
    t.index ["subject_id"], name: "index_revision_topics_on_subject_id"
  end

  create_table "ruby_llm_batches", force: :cascade do |t|
    t.string "batch_protocol"
    t.jsonb "chat_ids", default: []
    t.string "chat_type"
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.string "provider", null: false
    t.string "provider_batch_id", null: false
    t.string "raw_status"
    t.jsonb "reported_cost"
    t.jsonb "request_counts"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_batch_id"], name: "index_ruby_llm_batches_on_provider_and_provider_batch_id", unique: true
    t.index ["status"], name: "index_ruby_llm_batches_on_status"
  end

  create_table "ruby_llm_mcp_credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "data"
    t.string "key", null: false
    t.bigint "owner_id"
    t.string "owner_type"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_ruby_llm_mcp_credentials_on_key", unique: true
    t.index ["owner_type", "owner_id"], name: "index_ruby_llm_mcp_credentials_on_owner"
  end

  create_table "ruby_llm_models", force: :cascade do |t|
    t.jsonb "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.jsonb "metadata", default: {}
    t.jsonb "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.jsonb "pricing", default: {}
    t.string "provider", null: false
    t.datetime "unlisted_at"
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_ruby_llm_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_ruby_llm_models_on_family"
    t.index ["modalities"], name: "index_ruby_llm_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_ruby_llm_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_ruby_llm_models_on_provider"
  end

  create_table "ruby_llm_provider_files", force: :cascade do |t|
    t.string "account", null: false
    t.string "blob_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.text "file_id", null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["blob_key", "provider", "account"], name: "index_ruby_llm_provider_files_uniqueness", unique: true
  end

  create_table "ruby_llm_tool_calls", force: :cascade do |t|
    t.string "approval"
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.jsonb "mcp_result"
    t.jsonb "mcp_state"
    t.bigint "message_id", null: false
    t.string "message_type", null: false
    t.string "name", null: false
    t.boolean "remote", default: false, null: false
    t.bigint "result_id"
    t.string "result_type"
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_type", "message_id"], name: "index_ruby_llm_tool_calls_on_message_type_and_message_id"
    t.index ["name"], name: "index_ruby_llm_tool_calls_on_name"
    t.index ["result_type", "result_id"], name: "index_ruby_llm_tool_calls_on_result_type_and_result_id"
    t.index ["tool_call_id"], name: "index_ruby_llm_tool_calls_on_tool_call_id", unique: true
  end

  create_table "ruby_llm_usages", force: :cascade do |t|
    t.decimal "cache_read_cost", precision: 16, scale: 10
    t.integer "cache_read_tokens"
    t.decimal "cache_write_cost", precision: 16, scale: 10
    t.integer "cache_write_tokens"
    t.bigint "chat_id"
    t.string "chat_type"
    t.datetime "created_at", null: false
    t.decimal "input_cost", precision: 16, scale: 10
    t.integer "input_tokens"
    t.bigint "message_id"
    t.string "message_type"
    t.string "model", null: false
    t.string "operation", null: false
    t.decimal "output_cost", precision: 16, scale: 10
    t.integer "output_tokens"
    t.bigint "owner_id"
    t.string "owner_type"
    t.string "provider", null: false
    t.jsonb "server_tool_use"
    t.string "status", null: false
    t.decimal "thinking_cost", precision: 16, scale: 10
    t.integer "thinking_tokens"
    t.decimal "total_cost", precision: 16, scale: 10
    t.datetime "updated_at", null: false
    t.index ["chat_type", "chat_id"], name: "index_ruby_llm_usages_on_chat_type_and_chat_id"
    t.index ["message_type", "message_id"], name: "index_ruby_llm_usages_on_message_type_and_message_id"
    t.index ["owner_type", "owner_id"], name: "index_ruby_llm_usages_on_owner_type_and_owner_id"
    t.index ["status"], name: "index_ruby_llm_usages_on_status"
    t.check_constraint "operation::text = ANY (ARRAY['chat'::text, 'embedding'::text, 'moderation'::text, 'image'::text, 'speech'::text, 'transcription'::text, 'ocr'::text, 'rerank'::text, 'judgment'::text, 'video'::text, 'research'::text])"
    t.check_constraint "status::text = ANY (ARRAY['pending'::text, 'succeeded'::text, 'failed'::text, 'cancelled'::text])"
  end

  create_table "subjects", force: :cascade do |t|
    t.integer "baseline_remaining_lectures"
    t.string "code", null: false
    t.string "lecture_status"
    t.string "mock1_status"
    t.string "mock2_status"
    t.string "name", null: false
    t.integer "remaining_lectures", default: 0, null: false
    t.integer "total_lectures", default: 0, null: false
    t.bigint "user_id", null: false
    t.index ["id", "user_id"], name: "index_subjects_on_id_and_user_id", unique: true
    t.index ["user_id", "code"], name: "index_subjects_on_user_id_and_code", unique: true
    t.index ["user_id", "name"], name: "index_subjects_on_user_id_and_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chats", "ruby_llm_models"
  add_foreign_key "daily_morning_mails", "users"
  add_foreign_key "messages", "chats"
  add_foreign_key "milestone_subject_task_items", "milestones"
  add_foreign_key "milestone_subject_tasks", "milestones", column: ["milestone_id", "user_id"], primary_key: ["id", "user_id"], name: "fk_tasks_milestone_user"
  add_foreign_key "milestone_subject_tasks", "subjects", column: ["subject_id", "user_id"], primary_key: ["id", "user_id"], name: "fk_tasks_subject_user"
  add_foreign_key "milestone_subject_tasks", "users"
  add_foreign_key "milestones", "users"
  add_foreign_key "mock_test_results", "subjects"
  add_foreign_key "revision_topics", "subjects"
  add_foreign_key "subjects", "users"
end
