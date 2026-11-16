# Builds a DayPlan with its four fixed study slots, module-aware and
# goal-driven. Unlike a static weekly rotation, each slot walks a chain of
# subjects: it serves the next pending MODULE of the current subject, and when
# a subject's modules for that task type are exhausted it rolls on to the next
# subject in the chain. Daily pace is recomputed against the exam date, so when
# the student falls behind, each block packs more modules to stay on target.
#
# Fixed template (the four daily slots):
#   Block 1  09:00-12:00  Lecture   GST   -> IBS
#   Block 2  13:00-16:00  Lecture   DT    -> IBS
#   Block 3  16:30-17:30  Revision  FR -> AFM -> AUDIT -> DT -> GST -> IBS
#   Block 4  19:00-21:00  Lecture   AUDIT -> IBS
#
# Phases the plan walks through: finish all lectures -> revision 1 of the whole
# course -> mocks + revision 2. FR & AFM lectures are already done (revision
# phase); the live lecture focus is GST, AUDIT, DT, then IBS.
#
# Lecture slots, once their lecture chains are exhausted, fall back to the
# revision cascade so no block is ever wasted.
class DayPlanGenerator
  # Block index => [subject_chain, slot_type]. For a lecture slot the first
  # subject in the chain with remaining lecture modules wins; when done it rolls
  # to the next (IBS last, since its lectures aren't started yet).
  SLOTS = [
    { type: :lecture,  chain: %w[GST IBS] },   # Block 1
    { type: :lecture,  chain: %w[DT IBS] },    # Block 2
    { type: :revision, chain: nil },           # Block 3 (revision cascade)
    { type: :lecture,  chain: %w[AUDIT IBS] }  # Block 4
  ].freeze

  # Subject order the revision slot cascades through (used for rev1 then rev2).
  REVISION_CHAIN = %w[FR AFM AUDIT DT GST IBS].freeze

  # Clock times for the four blocks on a normal day.
  BLOCK_TIMES = [
    [ "09:00", "12:00" ],
    [ "13:00", "16:00" ],
    [ "16:30", "17:30" ],
    [ "19:00", "21:00" ]
  ].freeze

  # Health/hygiene is never allowed to crowd out study; capped regardless.
  MAX_MODULES_PER_BLOCK = 3

  def initialize(date, today: Date.current)
    @date  = date
    @today = today
    @road  = RoadmapService.new(today: today)
    # Running tally of modules we've "consumed" while planning THIS day, so a
    # single generate! call doesn't hand the same module to two blocks.
    @consumed = Hash.new(0) # [subject_code, task_type] => modules planned today
  end

  def generate!
    plan = DayPlan.find_or_initialize_by(date: @date)
    plan.kind = default_kind if plan.new_record?
    plan.save!

    if plan.task_items.empty?
      build_blocks(plan)
      build_makeup_blocks(plan) # weekend catch-up for skipped slots
      add_health_block(plan)
    end
    plan
  end

  private

  def default_kind
    @date.sunday? ? "sunday" : "normal"
  end

  # Exactly one module per block: one lecture per subject, one revision unit.
  # (Pace is managed by which subjects fill the blocks, not by cramming more
  # modules into a single block.)
  def modules_per_block
    1
  end

  def build_blocks(plan)
    per = modules_per_block

    SLOTS.each_with_index do |slot, i|
      assignment =
        if slot[:type] == :lecture
          # A lecture slot that's run out of lectures helps with revision.
          next_lecture_assignment(slot[:chain]) || next_revision_assignment
        else
          next_revision_assignment
        end
      create_block(plan, i + 1, assignment, per)
    end
  end

  # On weekends, add extra make-up blocks to clear skipped-slot backlog. A
  # lecture is a fixed 3-hr slot, so backlog is recovered by adding slots here
  # (not by cramming weekdays). Each make-up block serves the next pending
  # lecture, else the next revision module.
  def build_makeup_blocks(plan)
    makeup = BacklogService.makeup_blocks_for(@date)
    return if makeup.zero?

    makeup.times do
      assignment = next_lecture_assignment(all_lecture_chain) || next_revision_assignment
      break unless assignment
      block_no = plan.task_items.count + 1
      subject, type, first_module = assignment
      @consumed[[ subject.code, type ]] += 1
      plan.task_items.create!(
        block: block_no, subject: subject,
        activity: "Catch-up · #{activity_label(subject, type, first_module, first_module)}",
        kind: task_kind(type),
        start_time: nil, end_time: nil
      )
    end
  end

  # Every subject with lectures left, in chain order (for make-up slots, which
  # aren't tied to a specific weekday lecture slot).
  def all_lecture_chain
    REVISION_CHAIN
  end

  # First subject in the chain that still has lecture modules left.
  # Returns [subject, "lecture", module_number] or nil if the chain is done.
  def next_lecture_assignment(chain)
    chain.each do |code|
      goal = goal_for(code, "lecture")
      next unless goal
      done = goal.units_done + @consumed[[ code, "lecture" ]]
      return [ goal.subject, "lecture", done + 1 ] if done < goal.units_total
    end
    nil
  end

  # Revision cascade: all subjects' rev1 first, then all rev2. Returns
  # [subject, "revision_1"|"revision_2", module_number] or nil when all done.
  def next_revision_assignment
    %w[revision_1 revision_2].each do |type|
      REVISION_CHAIN.each do |code|
        goal = goal_for(code, type)
        next unless goal
        done = goal.units_done + @consumed[[ code, type ]]
        return [ goal.subject, type, done + 1 ] if done < goal.units_total
      end
    end
    # Everything revised: fall back to mocks so the block still earns progress.
    mock_assignment
  end

  def mock_assignment
    REVISION_CHAIN.each do |code|
      goal = goal_for(code, "mock")
      next unless goal
      done = goal.units_done + @consumed[[ code, "mock" ]]
      return [ goal.subject, "mock", done + 1 ] if done < goal.units_total
    end
    nil
  end

  # Create one block covering `per` consecutive modules of the assignment.
  def create_block(plan, block_no, assignment, per)
    start_t, end_t = BLOCK_TIMES[block_no - 1]

    if assignment.nil?
      # Nothing pending anywhere — a free block for backlog / rest.
      plan.task_items.create!(
        block: block_no, subject: nil,
        activity: "Backlog / buffer", kind: "backlog",
        start_time: start_t, end_time: end_t
      )
      return
    end

    subject, type, first_module = assignment
    last_module = modules_to_cover(subject, type, first_module, per)
    @consumed[[ subject.code, type ]] += (last_module - first_module + 1)

    plan.task_items.create!(
      block: block_no,
      subject: subject,
      activity: activity_label(subject, type, first_module, last_module),
      kind: task_kind(type),
      start_time: start_t, end_time: end_t
    )
  end

  # Don't cover more modules than the subject actually has left.
  def modules_to_cover(subject, type, first_module, per)
    goal = goal_for(subject.code, type)
    cap  = goal ? goal.units_total : first_module
    [ first_module + per - 1, cap ].min
  end

  def activity_label(subject, type, first_module, last_module)
    # Revision rounds show the actual chapter name, e.g.
    #   "FR revision R1 · Ch 1: Introduction to Ind AS"
    if %w[revision_1 revision_2].include?(type) && first_module == last_module
      round = type == "revision_1" ? "R1" : "R2"
      ch = chapter_name(subject, first_module)
      label = "#{subject.code} revision #{round} · Ch #{first_module}"
      label += ": #{ch}" if ch
      return label
    end

    span = first_module == last_module ? "##{first_module}" : "##{first_module}–#{last_module}"
    noun =
      case type
      when "lecture"    then "lecture"
      when "revision_1" then "revision R1 · Ch"
      when "revision_2" then "revision R2 · Ch"
      when "mock"       then "mock test"
      else "revision"
      end
    "#{subject.code} #{noun} #{span}"
  end

  # Map a goal task_type to the TaskItem.kind the tick-sync understands.
  # NOTE: TaskItem#goal_task_type reads "second"/"rev 2" from the activity to
  # tell rev1 from rev2, which activity_label already includes.
  def task_kind(type)
    case type
    when "lecture" then "lecture"
    when "mock"    then "mock"
    else "revision"
    end
  end

  def add_health_block(plan)
    plan.task_items.create!(
      block: plan.task_items.count + 1,
      activity: "Walk + water + 7h sleep",
      kind: "health",
      start_time: nil,
      end_time: nil
    )
  end

  def goal_for(code, type)
    (@goals ||= {})[[ code, type ]] ||= begin
      subject = subjects[code]
      subject && subject.syllabus_goals.find_by(task_type: type)
    end
  end

  # Name of the Nth revision chapter for a subject (revision module N = the Nth
  # chapter in order). Returns nil if there's no stored chapter at that position.
  def chapter_name(subject, module_number)
    list = (@chapters ||= {})[subject.code] ||= subject.revision_modules.order(:chapter_no).to_a
    list[module_number - 1]&.name
  end

  def subjects
    @subjects ||= Subject.all.index_by(&:code)
  end
end
