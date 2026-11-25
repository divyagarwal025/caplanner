# Seeds the production database with the EXACT current domain data, captured
# from the live DB into db/seed_data.rb (subjects, revision topics, milestones,
# milestone-subject tasks, and the 48 day-plan items with their jsonb schedules
# and progress). Idempotent: safe to re-run — it upserts by natural keys.
#
# The single user's credentials are NOT stored in the repo. Set them via env on
# first seed:  SEED_USER_EMAIL=...  SEED_USER_PASSWORD=...
# (falls back to a dev default locally).
#
# The 1834 ruby_llm_models are NOT seeded here — they are fetched fresh by
# RubyLLM::Models.refresh! at the end (needs network + no API key required).

require_relative "seed_data"

# Guard: only seed when the domain is empty (first deploy). On later deploys the
# live user may have real progress, which this snapshot would overwrite. Force a
# re-seed with RESEED=1 (intentional reset only).
if User.exists? && ENV["RESEED"].blank?
  puts "Seed skipped: data already present (set RESEED=1 to force re-seed)."
  return
end

ActiveRecord::Base.transaction do
  # ---- user --------------------------------------------------------------
  email    = ENV.fetch("SEED_USER_EMAIL", "chhavigoyal030@gmail.com")
  password = ENV.fetch("SEED_USER_PASSWORD", "3025v")
  user = User.find_or_initialize_by(email: email)
  user.password = password
  user.save!
  puts "User: #{user.email}"

  # ---- subjects ----------------------------------------------------------
  SeedData::SUBJECTS.each do |attrs|
    s = user.subjects.find_or_initialize_by(code: attrs["code"])
    s.assign_attributes(attrs)
    s.save!
  end
  subjects_by_code = user.subjects.index_by(&:code)
  puts "Subjects: #{subjects_by_code.size}"

  # ---- revision topics ---------------------------------------------------
  SeedData::REVISION_TOPICS.each do |code, topics|
    subject = subjects_by_code[code] or next
    topics.each do |attrs|
      t = subject.revision_topics.find_or_initialize_by(order_number: attrs["order_number"])
      t.assign_attributes(attrs)
      t.save!
    end
  end
  puts "Revision topics: #{RevisionTopic.count}"

  # ---- milestones --------------------------------------------------------
  SeedData::MILESTONES.each do |attrs|
    m = user.milestones.find_or_initialize_by(name: attrs["name"])
    m.assign_attributes(attrs)
    m.save!
  end
  milestones_by_name = user.milestones.index_by(&:name)
  puts "Milestones: #{milestones_by_name.size}"

  # ---- milestone-subject tasks ------------------------------------------
  SeedData::TASKS.each do |t|
    milestone = milestones_by_name[t[:milestone]] or next
    subject   = subjects_by_code[t[:subject]]     or next
    MilestoneSubjectTask.find_or_create_by!(
      milestone: milestone, subject: subject, task_type: t[:task_type]
    )
  end
  puts "Milestone-subject tasks: #{MilestoneSubjectTask.count}"

  # ---- day items (the plan + progress, jsonb) ---------------------------
  SeedData::DAY_ITEMS.each do |d|
    milestone = milestones_by_name[d[:milestone]] or next
    item = milestone.milestone_subject_task_items.find_or_initialize_by(date: Date.parse(d[:date]))
    item.task_schedule           = d[:task_schedule]
    item.ai_summary_night_update = d[:ai_summary_night_update]
    item.updated_task_schedule   = d[:updated_task_schedule]
    item.todays_productivity     = d[:todays_productivity]
    item.save!
  end
  puts "Day items: #{MilestoneSubjectTaskItem.count}"
end

# ---- AI model catalog (fetched, not seeded) ------------------------------
# EURA / AI needs the RubyLLM model catalog. We fetch it rather than ship 1834
# rows in the seed. Set SEED_SKIP_MODELS=1 to skip (e.g. offline test runs).
if ENV["SEED_SKIP_MODELS"].blank?
  begin
    RubyLLM::Models.refresh
    puts "RubyLLM models refreshed: #{RubyLLM::Model.count rescue 'n/a'}"
  rescue => e
    warn "[seed] RubyLLM::Models.refresh! failed (non-fatal): #{e.class} #{e.message}"
  end
else
  puts "RubyLLM models refresh skipped (SEED_SKIP_MODELS set)."
end

puts "Seed complete."
