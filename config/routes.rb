Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]

  # 本実装（タスク機能）
  root "tasks#new"

  resources :tasks, only: %i[index new create edit update destroy]

  # 画面モック（段階的に移行中）
  # get "tasks" => "mocks#my_tasks", as: :my_tasks_mock
  get "tasks/sample" => "mocks#task_detail", as: :task_detail_mock
  get "signup" => "mocks#signup", as: :signup_mock
  post "signup" => "mocks#signup_submit"
  get "login" => "mocks#login", as: :login_mock
  post "login" => "mocks#login_submit"
  get "terms" => "mocks#terms", as: :terms_mock
  get "privacy" => "mocks#privacy", as: :privacy_mock

  get "up" => "rails/health#show", as: :rails_health_check
end
