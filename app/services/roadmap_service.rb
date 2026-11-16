# The goal-driven view of the preparation: what's left across lectures,
# two revisions and mocks, how many days remain to the exam, and the pace
# needed to finish on time. Used by both the Roadmap page and the AI planner.
#
# Phase policy (chosen by the user):
#   Lectures -> Revision 1 -> (Mocks + Revision 2 together) near the end.
class RoadmapService
  # Fraction of remaining days reserved for the mocks+rev2 end phase.
  END_PHASE_FRACTION = 0.35

  def initialize(setting = Setting.instance, today: Date.current)
    @setting = setting
    @today   = today
  end

  def days_left
    [ @setting.days_to_exam(@today), 0 ].max
  end

  def exam_date
    @setting.exam_on
  end

  # Aggregate remaining units per task_type across all subjects.
  def remaining_by_type
    SyllabusGoal::TASK_TYPES.index_with do |type|
      SyllabusGoal.of_type(type).sum("units_total - units_done").clamp(0, Float::INFINITY).to_i
    end
  end

  def totals_by_type
    SyllabusGoal::TASK_TYPES.index_with { |type| SyllabusGoal.of_type(type).sum(:units_total) }
  end

  def done_by_type
    SyllabusGoal::TASK_TYPES.index_with { |type| SyllabusGoal.of_type(type).sum(:units_done) }
  end

  def total_remaining
    remaining_by_type.values.sum
  end

  # Units/day needed to clear everything that's left before the exam.
  def required_pace
    return total_remaining if days_left.zero?
    (total_remaining.to_f / days_left).ceil
  end

  # Which phase we're in, based on what's still pending and days left.
  def current_phase
    rem = remaining_by_type
    if rem["lecture"].positive?
      :lectures
    elsif in_end_window? || rem["revision_1"].zero?
      :mocks_and_rev2
    else
      :revision_1
    end
  end

  def phase_label
    { lectures: "Finish pending lectures",
      revision_1: "First revision of all papers",
      mocks_and_rev2: "Mocks + second revision" }[current_phase]
  end

  # Priority order of task types for planning, given the current phase.
  def priority_types
    case current_phase
    when :lectures       then %w[lecture revision_1 revision_2 mock]
    when :revision_1     then %w[revision_1 lecture revision_2 mock]
    when :mocks_and_rev2 then %w[mock revision_2 revision_1 lecture]
    end
  end

  # True once we're inside the final slice reserved for mocks + rev2.
  def in_end_window?
    return false if days_left.zero?
    end_days = (total_horizon * END_PHASE_FRACTION).ceil
    days_left <= end_days
  end

  def on_track?
    required_pace <= realistic_daily_capacity
  end

  # Subjects furthest behind for the current phase's leading task type.
  def focus_subjects(limit = 3)
    lead = priority_types.first
    SyllabusGoal.of_type(lead)
                .where("units_done < units_total")
                .sort_by { |g| -g.remaining }
                .first(limit)
                .map { |g| g.subject.code }
  end

  private

  # Study days originally available; used to size the end window.
  # Baseline = the start of the preparation timetable (25 Aug 2026).
  PREP_START = Date.new(2026, 8, 25)

  def total_horizon
    [ (@setting.exam_on - PREP_START).to_i, days_left ].max
  end

  # ~4 study blocks/day; treat each block as one unit of capacity.
  def realistic_daily_capacity
    4
  end
end
