require "test_helper"

class NextDayPlannerTest < ActiveSupport::TestCase
  setup do
    Setting.instance.update!(exam_date: Date.new(2027, 5, 2))
    @subjects = %w[GST FR AUDIT DT AFM IBS].each_with_index.map do |c, i|
      s = Subject.create!(code: c, name: c, position: i, lectures_total: 70, lectures_done: 10)
      SyllabusGoal.create!(subject: s, task_type: "lecture",    units_total: 70, units_done: 10, position: i * 10)
      SyllabusGoal.create!(subject: s, task_type: "revision_1", units_total: 70, units_done: 0,  position: i * 10 + 1)
      SyllabusGoal.create!(subject: s, task_type: "revision_2", units_total: 70, units_done: 0,  position: i * 10 + 2)
      SyllabusGoal.create!(subject: s, task_type: "mock",       units_total: 2,  units_done: 0,  position: i * 10 + 3)
      s
    end
  end

  test "falls back to fixed-template rule engine when no API key" do
    ENV.delete("GROQ_API_KEY")
    ENV.delete("OPENAI_API_KEY")
    result = NextDayPlanner.new(Date.new(2026, 11, 1), today: Date.new(2026, 10, 31)).call
    assert_equal :fallback, result.source
    plan = result.plan
    assert_equal 5, plan.task_items.count # 4 study + 1 health
    refute plan.ai_generated
    assert plan.ai_summary.include?("Planned")
  end

  test "lectures phase schedules lecture blocks for behind subjects" do
    ENV.delete("GROQ_API_KEY")
    ENV.delete("OPENAI_API_KEY")
    result = NextDayPlanner.new(Date.new(2026, 11, 1), today: Date.new(2026, 10, 31)).call
    kinds = result.plan.task_items.studyable.map(&:kind)
    assert_includes kinds, "lecture"
  end

  test "writes AI blocks and summary when LLM responds" do
    ENV["GROQ_API_KEY"] = "stub"
    planner = NextDayPlanner.new(Date.new(2026, 11, 2), today: Date.new(2026, 11, 1))
    planner.define_singleton_method(:ask_llm) do
      { "summary" => "exam-goal plan",
        "blocks" => [ { "start_time" => "10:00", "end_time" => "13:00", "subject_code" => "GST",
                        "activity" => "GST lecture", "kind" => "lecture" } ] }
    end
    result = planner.call
    assert_equal :ai, result.source
    assert result.plan.ai_generated
    assert_equal "exam-goal plan", result.plan.ai_summary
  ensure
    ENV.delete("GROQ_API_KEY")
  end

  test "ticking a lecture block advances its syllabus goal" do
    gst = @subjects.find { |s| s.code == "GST" }
    goal = gst.syllabus_goals.find_by(task_type: "lecture")
    plan = DayPlan.create!(date: Date.new(2026, 11, 1), kind: "normal")
    task = plan.task_items.create!(block: 1, subject: gst, activity: "GST lecture", kind: "lecture")

    assert_difference -> { goal.reload.units_done }, 1 do
      task.update!(done: true)
    end
    assert_difference -> { goal.reload.units_done }, -1 do
      task.update!(done: false)
    end
  end
end
