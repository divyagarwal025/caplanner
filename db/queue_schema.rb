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

ActiveRecord::Schema[8.1].define(version: 2026_11_16_101655) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "day_plans", force: :cascade do |t|
    t.boolean "ai_generated", default: false, null: false
    t.text "ai_summary"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "kind", default: "normal", null: false
    t.string "note"
    t.boolean "planned", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_day_plans_on_date", unique: true
  end

  create_table "night_updates", force: :cascade do |t|
    t.integer "blocks_done", default: 0, null: false
    t.integer "blocks_total", default: 0, null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "done_summary"
    t.boolean "processed", default: false, null: false
    t.text "raw_text"
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_night_updates_on_date", unique: true
  end

  create_table "productivity_logs", force: :cascade do |t|
    t.integer "blocks_done", default: 0, null: false
    t.integer "blocks_total", default: 0, null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "mood"
    t.text "notes"
    t.boolean "sleep_ok", default: false, null: false
    t.datetime "updated_at", null: false
    t.boolean "walked", default: false, null: false
    t.boolean "water_ok", default: false, null: false
    t.index ["date"], name: "index_productivity_logs_on_date", unique: true
  end

  create_table "revision_modules", force: :cascade do |t|
    t.integer "chapter_no", null: false
    t.datetime "created_at", null: false
    t.integer "expected_days", default: 3, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "revision_1_done", default: false, null: false
    t.boolean "revision_2_done", default: false, null: false
    t.bigint "subject_id", null: false
    t.datetime "updated_at", null: false
    t.index ["subject_id", "chapter_no"], name: "index_revision_modules_on_subject_id_and_chapter_no", unique: true
    t.index ["subject_id"], name: "index_revision_modules_on_subject_id"
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.integer "evening_hour", default: 22, null: false
    t.date "exam_date"
    t.integer "morning_hour", default: 7, null: false
    t.string "timezone", default: "Asia/Kolkata", null: false
    t.datetime "updated_at", null: false
  end

  create_table "subjects", force: :cascade do |t|
    t.string "code", null: false
    t.string "color", default: "#64748b", null: false
    t.datetime "created_at", null: false
    t.integer "lectures_done", default: 0, null: false
    t.integer "lectures_total", default: 0, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_subjects_on_code", unique: true
  end

  create_table "syllabus_goals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.integer "subject_id", null: false
    t.string "task_type", null: false
    t.integer "units_done", default: 0, null: false
    t.integer "units_total", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["subject_id", "task_type"], name: "index_syllabus_goals_on_subject_id_and_task_type", unique: true
    t.index ["subject_id"], name: "index_syllabus_goals_on_subject_id"
  end

  create_table "task_items", force: :cascade do |t|
    t.string "activity", null: false
    t.integer "actual_minutes"
    t.integer "block", default: 1, null: false
    t.datetime "created_at", null: false
    t.integer "day_plan_id", null: false
    t.boolean "done", default: false, null: false
    t.datetime "done_at"
    t.string "end_time"
    t.string "kind", default: "lecture", null: false
    t.boolean "pending", default: false, null: false
    t.integer "planned_minutes"
    t.integer "rescheduled_from_id"
    t.string "start_time"
    t.integer "subject_id"
    t.datetime "updated_at", null: false
    t.index ["day_plan_id", "block"], name: "index_task_items_on_day_plan_id_and_block"
    t.index ["day_plan_id"], name: "index_task_items_on_day_plan_id"
    t.index ["rescheduled_from_id"], name: "index_task_items_on_rescheduled_from_id"
    t.index ["subject_id"], name: "index_task_items_on_subject_id"
  end

  add_foreign_key "revision_modules", "subjects"
  add_foreign_key "syllabus_goals", "subjects"
  add_foreign_key "task_items", "day_plans"
  add_foreign_key "task_items", "subjects"
  add_foreign_key "task_items", "task_items", column: "rescheduled_from_id"
end
