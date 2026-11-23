# Rolls the day's block states up into subject / revision-topic status. Runs
# only when the user saves a day (MilestoneSubjectTaskItem#save_day!), never on
# each block click.
#
# Block status -> effect:
#   done            -> the work is complete
#   partially_done  -> the work is in progress
#   not_started     -> no effect
#
# To stay correct across repeated saves, counters are RECOMPUTED from the full
# history of the user's day-items rather than incremented:
#   - lectures: remaining_lectures = total - (# of that subject's lecture blocks
#     marked done across all days); lecture_status derived from that.
#   - mocks: mock1/mock2_status set from done mock blocks for the subject.
#   - revision: the first N pending RevisionTopics (in order) for a round are
#     marked done, where N = # of that subject's done revision blocks for the
#     round; partially-done revision marks the next topic in_progress.
#
# "No AI, assume completion" friendly: idempotent and deterministic.
class ProgressRollup
  def initialize(item)
    @item     = item
    @user     = User.current
    @subjects = @user.subjects.index_by(&:code)
  end

  def apply!
    @subjects.each_value do |subject|
      roll_lectures(subject)
      roll_mocks(subject)
      roll_revision(subject, round: 1)
      roll_revision(subject, round: 2)
    end
  end

  private

  # All of this user's day-items (across every milestone), newest-agnostic.
  def all_items
    @all_items ||= MilestoneSubjectTaskItem
                     .joins(:milestone)
                     .where(milestones: { user_id: @user.id })
                     .to_a
  end

  # Count this user's blocks for a subject that are `done` and match a filter.
  def done_count(subject_code, kind:, round: nil)
    all_items.sum do |item|
      item.blocks.count do |b|
        next false unless b["subject_code"] == subject_code
        next false unless b["status"] == "done"
        next false unless b["kind"] == kind
        round.nil? || revision_round(b) == round
      end
    end
  end

  def any_partial?(subject_code, kind:, round: nil)
    all_items.any? do |item|
      item.blocks.any? do |b|
        b["subject_code"] == subject_code && b["status"] == "partially_done" &&
          b["kind"] == kind && (round.nil? || revision_round(b) == round)
      end
    end
  end

  # Rev round inferred from the activity text (R2/second => 2, else 1).
  def revision_round(block)
    block["activity"].to_s.match?(/second|rev.?2|r2|revision 2/i) ? 2 : 1
  end

  # ---- lectures -------------------------------------------------------------

  def roll_lectures(subject)
    done      = done_count(subject.code, kind: "lecture")
    baseline  = subject.baseline_remaining_lectures || subject.remaining_lectures
    remaining = [ baseline - done, 0 ].max
    status =
      if remaining.zero? && subject.total_lectures.positive? then "done"
      elsif done.positive? || any_partial?(subject.code, kind: "lecture") then "in_progress"
      else subject.lecture_status.presence || "not_started"
      end
    subject.update!(remaining_lectures: remaining, lecture_status: status)
  end

  # ---- mocks ----------------------------------------------------------------

  def roll_mocks(subject)
    done = done_count(subject.code, kind: "mock")
    subject.update!(mock1_status: done >= 1 ? "done" : subject.mock1_status.presence || "not_started")
    subject.update!(mock2_status: done >= 2 ? "done" : subject.mock2_status.presence || "not_started")
  end

  # ---- revision -------------------------------------------------------------

  def roll_revision(subject, round:)
    col     = "rev#{round}_status"
    topics  = subject.revision_topics.order(:order_number).to_a
    n_done  = done_count(subject.code, kind: "revision", round: round) +
              done_count(subject.code, kind: "questions", round: round)

    topics.each_with_index do |topic, i|
      target =
        if i < n_done then "done"
        elsif i == n_done && any_partial?(subject.code, kind: "revision", round: round) then "in_progress"
        else "not_started"
        end
      topic.update!(col => target) if topic.public_send(col) != target
    end
  end
end
