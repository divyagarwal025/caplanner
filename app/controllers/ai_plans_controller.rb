class AiPlansController < ApplicationController
  def create
    target = params[:date].present? ? Date.parse(params[:date]) : Date.current + 1
    result = NextDayPlanner.new(target).call

    notice =
      case result.source
      when :ai       then "AI planned #{target.strftime('%a %d %b')}: #{result.plan.ai_summary}"
      when :fallback then "Planned #{target.strftime('%a %d %b')} from your rotation" \
                          "#{" (AI unavailable: #{result.error})" if result.error}"
      end

    redirect_to day_plan_path(target.iso8601), notice: notice
  end
end
