# frozen_string_literal: true

Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]

  # 利用規約・プライバシーポリシー（ログイン前でも開ける）
  get "terms" => "pages#terms", as: :terms
  get "privacy" => "pages#privacy", as: :privacy

  # 本実装（タスク機能）
  root "tasks#new"
  # id は数値のみ（/tasks/sample のような文字列をタスク詳細として受けない）
  resources :tasks, constraints: { id: /\d+/ } do
    member do
      post :redecompose
    end

    # サブタスクの操作（タブ切り替え・追加・編集・削除・完了切り替え）
    scope module: :tasks do
      resources :subtasks, only: %i[index show new create edit update destroy] do
        member do
          patch :toggle_status
        end
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
