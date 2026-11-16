require_relative "revision_modules_data" # REVISION_MODULES (ICAI chapter lists)

# CA Final subjects, seeded with status from the master timetable.
# Status: FR/AFM lectures complete (now in revision); AUDIT/DT/GST lectures in
# progress; IBS lectures not started.
#
# `rev` = number of revision modules per subject (separate from the lecture
# count). Each subject gets `rev` modules for revision 1 AND `rev` for revision
# 2. Defaults to 10; adjust per subject here as the real counts are known.
subjects = [
  { code: "FR",    name: "Financial Reporting",             total: 60, done: 60, rev: 10, color: "#2563eb" },
  { code: "AFM",   name: "Advanced Financial Management",   total: 55, done: 55, rev: 10, color: "#7c3aed" },
  { code: "AUDIT", name: "Advanced Auditing",               total: 67, done: 29, rev: 10, color: "#db2777" },
  { code: "DT",    name: "Direct Tax",                      total: 70, done: 37, rev: 10, color: "#ea580c" },
  { code: "GST",   name: "Indirect Tax (GST)",              total: 70, done: 7,  rev: 10, color: "#16a34a" },
  { code: "IBS",   name: "Integrated Business Solutions",   total: 40, done: 0,  rev: 10, color: "#0891b2" }
]

# Goal matrix toward the exam: lectures (remaining course), two full revisions
# of every paper, and mock tests.
#   - lecture totals mirror the real lecture count (the primary focus)
#   - revision_1 / revision_2 totals = the subject's revision MODULE count
#     (`rev`), independent of how many lectures the subject has
#   - mocks: a fixed number per subject
MOCKS_PER_SUBJECT = 2

subjects.each_with_index do |s, i|
  subject = Subject.find_or_initialize_by(code: s[:code])
  subject.update!(
    name: s[:name],
    lectures_total: s[:total],
    lectures_done: s[:done],
    color: s[:color],
    position: i
  )

  # Revision modules = real ICAI chapters for this subject (if any). The number
  # of chapters becomes the revision goal total; IBS has none (case-study paper).
  chapters = REVISION_MODULES[s[:code]] || []
  chapters.each_with_index do |(ch_no, ch_name, days), ci|
    RevisionModule.find_or_initialize_by(subject: subject, chapter_no: ch_no).update!(
      name: ch_name, expected_days: days, position: ci
    )
  end
  rev_total = chapters.size.positive? ? chapters.size : s[:rev]

  goals = {
    "lecture"    => { total: s[:total], done: s[:done] },
    "revision_1" => { total: rev_total, done: 0 },
    "revision_2" => { total: rev_total, done: 0 },
    "mock"       => { total: MOCKS_PER_SUBJECT, done: 0 }
  }
  goals.each_with_index do |(type, v), gi|
    SyllabusGoal.find_or_initialize_by(subject: subject, task_type: type).update!(
      units_total: v[:total], units_done: v[:done], position: i * 10 + gi
    )
  end
end

Setting.instance.update!(exam_date: Setting::DEFAULT_EXAM_DATE) if Setting.instance.exam_date.nil?

puts "Seeded #{Subject.count} subjects, #{SyllabusGoal.count} goals, " \
     "#{RevisionModule.count} revision modules; exam #{Setting.instance.exam_on}."
