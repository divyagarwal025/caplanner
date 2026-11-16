# Read-only stats derived from productivity logs.
module ProductivityService
  module_function

  # Consecutive days up to today where completion was >= threshold.
  def current_streak(threshold: 70)
    streak = 0
    date = Date.current
    loop do
      log = ProductivityLog.find_by(date: date)
      break unless log && log.completion_percent >= threshold
      streak += 1
      date -= 1
    end
    streak
  end

  def week_completion_rate
    logs = ProductivityLog.where(date: (Date.current - 6)..Date.current)
    return 0 if logs.empty?
    (logs.sum(&:completion_percent) / logs.size.to_f).round
  end
end
