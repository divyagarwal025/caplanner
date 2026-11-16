class RoadmapController < ApplicationController
  def index
    @road     = RoadmapService.new
    @journey  = JourneyPlanner.new
    @guide    = JourneyGuide.new.call
    @subjects = Subject.all
  end
end
