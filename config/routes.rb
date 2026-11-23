Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  get "calendar(/:year/:month)", to: "calendar#index", as: :calendar
  get "analytics", to: "analytics#index", as: :analytics
  get "roadmap", to: "roadmap#index", as: :roadmap

  # The night report for a date (free text), which also triggers re-planning.
  resources :night_updates, only: %i[create], param: :date

  # A day's plan = the milestone_subject_task_item for that date.
  resources :day_plans, only: %i[show], param: :date do
    member do
      post :save
      post :regenerate
    end
  end

  # Set a single block's 3-state status within a day's jsonb schedule.
  patch "blocks/:date/:index", to: "blocks#update", as: :block

  # AI plans the next day (with deterministic fallback).
  post "plan_tomorrow", to: "ai_plans#create", as: :plan_tomorrow

  resources :subjects, only: %i[index update]
  resources :milestones, only: %i[index show new create edit update destroy]

  # Manual triggers to preview the scheduled emails.
  namespace :emails do
    post :morning
    post :evening
  end
end
