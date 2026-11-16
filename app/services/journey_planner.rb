# Plans the ENTIRE journey to the exam, not just tomorrow. Produces:
#   - phases (lectures -> revision 1 -> mocks + revision 2) with target end dates
#   - per-subject milestones (e.g. "GST lectures done by ~20 Dec")
#   - this week's rolling targets (module ranges per subject)
#   - an on-track / behind verdict against the exam date
#
# It is deterministic (arithmetic against remaining work, study capacity and
# days left) so the dates are always honest. AI guidance is layered on top by
# JourneyGuide, which reads this plan — the numbers here never depend on AI.
#
# Capacity model matches the fixed daily template: 3 lecture slots + 1 revision
# slot = 4 study blocks/day, one module per block.
class JourneyPlanner
  LECTURE_SLOTS_PER_DAY  = 3   # blocks 1,2,4
  REVISION_SLOTS_PER_DAY = 1   # block 3
  STUDY_DAYS_PER_WEEK    = 7   # plan assumes daily study; tune if rest days wanted

  # One extra study block on each weekend day (Sat+Sun). This catch-up capacity
  # is what lets the full scope — all lectures, BOTH revisions and mocks — finish
  # by the exam; it feeds the revision/mock phases. ~2 extra blocks/week.
  WEEKEND_BONUS_BLOCKS_PER_WEEK = 2

  Phase = Struct.new(:key, :label, :units, :days_needed, :start_date, :end_date, keyword_init: true)

  def initialize(setting = Setting.instance, today: Date.current)
    @setting = setting
    @today   = today
    @road    = RoadmapService.new(setting, today: today)
  end

  def exam_date = @setting.exam_on
  def days_left = [ (@setting.exam_on - @today).to_i, 0 ].max

  # Remaining units per phase (a phase can span multiple task types).
  def remaining
    rem = @road.remaining_by_type
    {
      lectures:        rem["lecture"].to_i,
      revision_1:      rem["revision_1"].to_i,
      mocks_and_rev2:  rem["revision_2"].to_i + rem["mock"].to_i
    }
  end

  # The three phases laid out on the calendar, back-to-back from today.
  #  - Lectures: module/slot-rate (1 lecture per slot, 3 lecture slots/day).
  #  - Revisions: sized by REAL chapter durations (sum of expected_days of the
  #    pending chapters), since a chapter takes 2-5 days — not one per slot.
  #    The revision slot plus any freed-up lecture slots do revision work in
  #    parallel, so days = ceil(revision_day_load / revision_slots_available).
  def phases
    cursor = @today
    [
      # Lectures use their 3 slots; the 1 revision slot runs revision alongside,
      # so part of revision_1 is already chipped away during the lecture phase.
      build_phase_by_units(:lectures, "Finish pending lectures", remaining[:lectures], LECTURE_SLOTS_PER_DAY, cursor) { |p| cursor = p.end_date + 1 },
      # Once lectures are done, ALL 4 slots plus the weekend bonus pour into
      # revision / mocks — this is what lets both revisions finish by the exam.
      build_phase_by_days(:revision_1, "First revision of all papers", revision_1_remaining_after_lectures, revision_slots_per_day, cursor) { |p| cursor = p.end_date + 1 },
      build_phase_by_days(:mocks_and_rev2, "Mocks + second revision", revision_day_load(2) + mock_day_load, revision_slots_per_day, cursor) { |p| cursor = p.end_date + 1 }
    ]
  end

  # Effective study blocks per day during revision phases: the 4 daily blocks
  # plus the weekend bonus spread across the week.
  def revision_slots_per_day
    slots_per_day + (WEEKEND_BONUS_BLOCKS_PER_WEEK / 7.0)
  end

  # Revision-1 day-load that remains AFTER the revision slot nibbles at it during
  # the lecture phase (1 revision slot/day for the length of the lecture phase).
  def revision_1_remaining_after_lectures
    lecture_days = remaining[:lectures].zero? ? 0 : (remaining[:lectures].to_f / LECTURE_SLOTS_PER_DAY).ceil
    # The dedicated revision slot (+ weekend bonus) chips at rev1 during lectures.
    rate = REVISION_SLOTS_PER_DAY + (WEEKEND_BONUS_BLOCKS_PER_WEEK / 7.0)
    done_during_lectures = (lecture_days * rate).floor
    [ revision_day_load(1) - done_during_lectures, 0 ].max
  end

  # Fraction of a chapter's first-pass days the SECOND revision takes. The 2nd
  # revision is faster (the base is already built), so rev2 ~= half of rev1.
  REVISION_2_SPEEDUP = 0.5

  # Total revision-DAYS of work left for a round, summing each pending chapter's
  # expected_days across all subjects. Round 2 applies the speed-up (min 1 day
  # per chapter so nothing rounds to zero).
  def revision_day_load(round)
    pending = RevisionModule.where("revision_#{round}_done" => false)
    return pending.sum(:expected_days) if round == 1

    pending.sum { |m| [ (m.expected_days * REVISION_2_SPEEDUP).ceil, 1 ].max }
  end

  def mock_day_load
    @road.remaining_by_type["mock"].to_i # ~1 day per mock
  end

  # Per-subject milestone dates within the lectures phase (the live focus).
  # Returns [{code, remaining, done_by}] ordered by the lecture chain.
  def lecture_milestones
    slot_rate = LECTURE_SLOTS_PER_DAY.to_f # modules/day across all lecture slots
    cursor_units = 0
    pending_lecture_goals.map do |g|
      cursor_units += g.remaining
      done_by = @today + (cursor_units / slot_rate).ceil
      { code: g.subject.code, remaining: g.remaining, done_by: [ done_by, exam_date ].min }
    end
  end

  # This week's target: how many modules to clear by week-end, matching the slot
  # structure. The 3 lecture slots (21 blocks/week) are spent on lectures first;
  # the 1 revision slot (7 blocks/week) is spent on the current revision/mock
  # focus. When lectures are finished, all 28 blocks go to revision/mocks.
  def weekly_targets
    week_end     = @today + 6
    lecture_cap  = LECTURE_SLOTS_PER_DAY * 7
    revision_cap = REVISION_SLOTS_PER_DAY * 7

    items = fill_budget(pending_lecture_goals, lecture_cap)

    # Any unused lecture capacity (lectures almost done) rolls into revision.
    leftover = lecture_cap - items.sum { |t| t[:modules] }
    items += fill_budget(pending_revision_goals, revision_cap + leftover)

    { week_of: @today, week_end: week_end, items: items }
  end

  # Will the whole journey fit before the exam at current capacity?
  def on_track?
    phases.last.end_date <= exam_date
  end

  # Days of slack (positive) or overrun (negative) vs the exam date.
  def buffer_days
    (exam_date - phases.last.end_date).to_i
  end

  def slots_per_day
    LECTURE_SLOTS_PER_DAY + REVISION_SLOTS_PER_DAY
  end

  private

  # Phase sized by module COUNT divided by slots/day (used for lectures:
  # 1 lecture per slot).
  def build_phase_by_units(key, label, units, slots_per_day, start_date)
    days = units.zero? ? 0 : (units.to_f / slots_per_day).ceil
    make_phase(key, label, units, days, start_date) { |p| yield p if block_given? }
  end

  # Phase sized by a DAY load (sum of chapter expected_days) divided by how many
  # revision slots run per day (used for revisions: a chapter takes 2-5 days).
  def build_phase_by_days(key, label, day_load, slots_per_day, start_date)
    days = day_load.zero? ? 0 : (day_load.to_f / slots_per_day).ceil
    make_phase(key, label, day_load, days, start_date) { |p| yield p if block_given? }
  end

  def make_phase(key, label, units, days, start_date)
    phase = Phase.new(key: key, label: label, units: units, days_needed: days,
                      start_date: start_date, end_date: start_date + [ days - 1, 0 ].max)
    yield phase if block_given?
    phase
  end

  def pending_lecture_goals
    order = DayPlanGenerator::REVISION_CHAIN # same subject order
    SyllabusGoal.of_type("lecture").where("units_done < units_total")
                .sort_by { |g| order.index(g.subject.code) || 99 }
  end

  # Revision/mock goals in phase-priority order (all rev1 first, then rev2, then
  # mocks — matching the daily revision cascade).
  def pending_revision_goals
    order = DayPlanGenerator::REVISION_CHAIN
    %w[revision_1 revision_2 mock].flat_map do |type|
      SyllabusGoal.of_type(type).where("units_done < units_total")
                  .sort_by { |g| order.index(g.subject.code) || 99 }
    end
  end

  # Spend `budget` blocks down a list of goals in order, producing target rows.
  def fill_budget(goals, budget)
    rows = []
    goals.each do |g|
      break if budget <= 0
      take = [ g.remaining, budget ].min
      from = g.units_done + 1
      rows << { code: g.subject.code, type: g.task_type,
                label: "#{g.subject.code} #{type_noun(g.task_type)} ##{from}–#{from + take - 1}",
                modules: take }
      budget -= take
    end
    rows
  end

  def type_noun(type)
    { "lecture" => "lecture", "revision_1" => "first revision",
      "revision_2" => "second revision", "mock" => "mock test" }.fetch(type, type)
  end
end
