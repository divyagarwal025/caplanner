# Tracks study backlog — the slots you skipped. A lecture is a fixed 3-hour
# slot and a chapter has a fixed day-timeline, so skipped work can't be
# "compressed"; it owes a make-up slot. Those make-up slots are served in the
# extra WEEKEND blocks (weekdays stay at the normal 4 slots), which protects the
# exam deadline without cramming weekdays.
#
# Backlog = count of past, unfinished studyable task blocks (marked pending when
# their day ended). Each one is one owed make-up slot.
module BacklogService
  module_function

  # How many study slots are owed (skipped on past days and never done).
  def owed_slots(before: Date.current)
    TaskItem.studyable
            .where(done: false)
            .joins(:day_plan)
            .where("day_plans.date < ?", before)
            .count
  end

  def any?(before: Date.current)
    owed_slots(before: before).positive?
  end

  # Make-up blocks to add to a given (weekend) day: capped so we don't dump the
  # entire backlog into one day. Spreads recovery across weekends.
  WEEKEND_MAKEUP_CAP = 2

  def makeup_blocks_for(date)
    return 0 unless weekend?(date)
    [ owed_slots(before: date), WEEKEND_MAKEUP_CAP ].min
  end

  def weekend?(date)
    date.saturday? || date.sunday?
  end
end
