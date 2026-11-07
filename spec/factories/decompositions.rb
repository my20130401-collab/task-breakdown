FactoryBot.define do
  factory :decomposition do
    # 関連付け: 親タスクを自動生成して紐付ける（Task 側のバリデーションも同時に満たす）
    association :task

    # 初期値の設定
    status { :pending }
    granularity { :normal }
    model { "gpt-5-mini" }
    request_payload { { prompt: "テストプロンプト" } }
    response_payload { nil }
    error_message { nil }

    # ステータスごとの状態（トレイト）
    # 分解成功時: レスポンス JSON が格納された状態を再現
    trait :succeeded do
      status { :succeeded }
      response_payload { { subtasks: [] } }
    end

    # 分解失敗時: エラーメッセージが記録された状態を再現
    trait :failed do
      status { :failed }
      error_message { "APIエラーが発生しました" }
    end
  end
end
