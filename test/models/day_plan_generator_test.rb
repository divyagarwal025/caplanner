require "test_helper"

class DayPlanGeneratorTest < ActiveSupport::TestCase
  setup do
    # Subjects with lecture + revision goals so the goal-driven generator has
    # pending modules to assign. GST/DT/AUDIT have lectures left; FR/AFM done.
    {
      "GST" => { total: 70, done: 7 }, "FR" => { total: 60, done: 60 },
      "AUDIT" => { total: 67, done: 29 }, "DT" => { total: 70, done: 37 },
      "AFM" => { total: 55, done: 55 }, "IBS" => { total: 40, done: 0 }
    }.each_with_index do |(code, l), i|
      s = Subject.create!(code: code, name: code, position: i,
                          lectures_total: l[:total], lectures_done: l[:done])
      SyllabusGoal.create!(subject: s, task_type: "lecture",    units_total: l[:total], units_done: l[:done], position: i * 10)
      SyllabusGoal.create!(subject: s, task_type: "revision_1", units_total: 10, units_done: 0, position: i * 10 + 1)
      SyllabusGoal.create!(subject: s, task_type: "revision_2", units_total: 10, units_done: 0, position: i * 10 + 2)
      SyllabusGoal.create!(subject: s, task_type: "mock",       units_total: 2,  units_done: 0, position: i * 10 + 3)
    end
  end

  test "generates four fixed study slots plus health, module-aware" do
    plan = DayPlanGenerator.new(Date.new(2026, 11, 16)).generate!

    assert_equal "normal", plan.kind
    assert_equal 5, plan.task_items.count
    assert_equal 4, plan.blocks_total

    first = plan.task_items.ordered.first
    assert_equal "GST", first.subject.code
    assert_equal "lecture", first.kind
    assert_match(/GST lecture #8/, first.activity) # next module after 7 done
  end

  test "lecture slots cover GST, DT, AUDIT and a revision block" do
    plan = DayPlanGenerator.new(Date.new(2026, 11, 16)).generate!
    codes = plan.task_items.ordered.map { |t| t.subject&.code }
    assert_equal %w[GST DT FR AUDIT], codes.compact.first(4) # FR leads revision cascade
  end

  test "DayPlan.for is idempotent" do
    date = Date.new(2026, 10, 20)
    first = DayPlan.for(date)
    second = DayPlan.for(date)
    assert_equal first.id, second.id
    assert_equal first.task_items.count, second.task_items.count
  end
end
