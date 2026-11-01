FactoryBot.define do
  # Task モデルのテストデータ生成テンプレート
  factory :task do
    association :user
    title { "テストタスク" }
    description { "タスクの補足説明です" }
    kind { :basic }
    status { :todo }
    source { :manual }
    position { 0 }
    # 過去日バリデーションに引っかからないよう未来（明日）を設定
    due_at { 1.day.from_now }

    # 用途別のバリエーション（Trait）
    trait :done do
      status { :done }
      completed_at { Time.current }
    end

    trait :without_due_at do
      due_at { nil }
    end

    trait :subtask do
      association :parent, factory: :task
    end
  end
end
