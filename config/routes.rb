Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  get "calendar(/:year/:month)", to: "calendar#index", as: :calendar
  get "analytics", to: "analytics#index", as: :analytics
  get "roadmap", to: "roadmap#index", as: :roadmap

  resources :night_updates, only: %i[create], param: :date
  resources :syllabus_goals, only: %i[update]

  resources :day_plans, only: %i[show], param: :date do
    member do
      post :regenerate
    end
  end

  # AI plans the next day (Groq, with rotation fallback).
  post "plan_tomorrow", to: "ai_plans#create", as: :plan_tomorrow

  resources :task_items, only: :update do
    member { patch :toggle }
  end

  resources :subjects, only: %i[index update]

  resources :productivity_logs, only: %i[index create update], param: :date

  resource :settings, only: %i[edit update]

  # Manual triggers to preview the scheduled emails.
  namespace :emails do
    post :morning
    post :evening
  end
end
