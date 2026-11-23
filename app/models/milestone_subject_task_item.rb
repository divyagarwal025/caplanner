# The per-date study plan — the new "DayPlan". The day's blocks live in the
# `task_schedule` jsonb (see shape below); there are no per-task DB rows.
#
# Each block has a 3-state `status`: not_started / partially_done / done.
# The user sets each block's status (set_block_status!), which only updates the
# jsonb. Progress is rolled up to subject / revision-topic status ONLY when the
# day is explicitly saved (#save_day!), via ProgressRollup.
#
# task_schedule shape:
#   { "summary" => "one-line rationale",
#     "blocks"  => [
#       { "block" => 1, "start_time" => "09:00", "end_time" => "12:00",
#         "subject_code" => "GST", "activity" => "GST lecture #4",
#         "kind" => "lecture", "status" => "not_started" }, ... ] }
#
# `updated_task_schedule` holds an AI re-plan proposed for the day (if any);
# `ai_summary_night_update` and `todays_productivity` capture the night report.
class MilestoneSubjectTaskItem < ApplicationRecord
  belongs_to :milestone

  STUDYABLE_KINDS = %w[lecture revision questions test mock backlog].freeze
  STATUSES = %w[not_started partially_done done].freeze

  validates :date, presence: true, uniqueness: { scope: :milestone_id }

  scope :chronological, -> { order(:date) }

  # --- jsonb accessors -------------------------------------------------------

  def summary
    schedule["summary"].to_s
  end

  def blocks
    Array(schedule["blocks"])
  end

  def studyable_blocks
    blocks.select { |b| STUDYABLE_KINDS.include?(b["kind"].to_s) }
  end

  def blocks_total
    studyable_blocks.size
  end

  def blocks_done
    studyable_blocks.count { |b| b["status"] == "done" }
  end

  # "done" counts 1.0, "partially_done" counts 0.5 toward completion.
  def completion_percent
    return 0 if blocks_total.zero?
    weighted = studyable_blocks.sum do |b|
      case b["status"]
      when "done" then 1.0
      when "partially_done" then 0.5
      else 0.0
      end
    end
    (weighted * 100 / blocks_total).round
  end

  def complete?
    blocks_total.positive? && blocks_done == blocks_total
  end

  # Replace the whole schedule (used by the planners / generator). Each block is
  # normalised to carry a status (defaults to not_started).
  def set_schedule!(summary:, blocks:)
    normalized = Array(blocks).each_with_index.map do |b, i|
      b = b.stringify_keys
      b["block"]  ||= i + 1
      b["status"]   = normalize_status(b["status"])
      b.delete("done")
      b
    end
    self.task_schedule = { "summary" => summary.to_s, "blocks" => normalized }
    save!
  end

  # Set one block's status (by zero-based index). Does NOT roll up — that only
  # happens on save_day!.
  def set_block_status!(index, status)
    bs = blocks
    block = bs[index] or return false
    block["status"] = normalize_status(status)
    self.task_schedule = schedule.merge("blocks" => bs)
    save!
    true
  end

  # Apply the whole day (optionally setting many block statuses at once from a
  # {index => status} hash), then roll the results up to subject / topic status.
  def save_day!(statuses = {})
    statuses.each { |i, s| set_block_status!(i.to_i, s) } if statuses.present?
    ProgressRollup.new(self).apply!
    self
  end

  private

  def normalize_status(value)
    s = value.to_s
    STATUSES.include?(s) ? s : "not_started"
  end

  # task_schedule may legitimately be {} (migration default); treat uniformly.
  def schedule
    task_schedule.presence || { "summary" => "", "blocks" => [] }
  end
end
