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

    # サブタスク。親と同じユーザーにしないと所有者一致のバリデーションに落ちる
    trait :subtask do
      association :parent, factory: :task
      user { parent.user }
      source { :ai }
    end

    # ---- S-4 の分解状態（親タスク用。画面の見え方ごとに用意する） ----

    # 分解中: 最新の分解履歴が pending で、サブタスクはまだ無い
    trait :decomposing do
      after(:create) do |task|
        create(:decomposition, task:, status: :pending)
      end
    end

    # 分解失敗: 最新の分解履歴が failed で、サブタスクは無い
    trait :decomposition_failed do
      after(:create) do |task|
        create(:decomposition, :failed, task:)
      end
    end

    # 分解完了: 3 件のサブタスク（特殊 1 件・完了 1 件・期限なし 1 件）
    trait :decomposed do
      after(:create) do |task|
        create(:decomposition, :succeeded, task:)
        due = task.due_at
        create(:task, :subtask, parent: task, title: "#{task.title}の手順1", kind: :special, due_at: due)
        create(:task, :subtask, :done, parent: task, title: "#{task.title}の手順2", due_at: due)
        create(:task, :subtask, :without_due_at, parent: task, title: "#{task.title}の手順3")
      end
    end

    # 全完了: 分解完了の後、サブタスクがすべて完了している（親も完了に同期される）
    trait :all_subtasks_done do
      after(:create) do |task|
        create(:decomposition, :succeeded, task:)
        2.times do |i|
          create(:task, :subtask, :done, parent: task, title: "#{task.title}の手順#{i + 1}", due_at: task.due_at)
        end
      end
    end
  end
end
