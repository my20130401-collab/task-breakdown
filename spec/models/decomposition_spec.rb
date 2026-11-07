require "rails_helper"

RSpec.describe Decomposition do
  describe "バリデーション" do
    # FactoryBot で定義した初期値が有効であることの確認
    it "有効な属性を持つ場合は有効であること" do
      decomposition = build(:decomposition)
      expect(decomposition).to be_valid
    end

    # 処理ステータス（pending / succeeded / failed）の必須チェック
    describe "ステータス（status）" do
      it "必須であること" do
        decomposition = build(:decomposition, status: nil)
        expect(decomposition).not_to be_valid
        expect(decomposition.errors[:status]).to be_present
      end
    end

    # 分解粒度（normal / finer / coarser）の必須チェック
    describe "分解粒度（granularity）" do
      it "必須であること" do
        decomposition = build(:decomposition, granularity: nil)
        expect(decomposition).not_to be_valid
        expect(decomposition.errors[:granularity]).to be_present
      end
    end

    # AI に送信した入力パラメータ（request_payload）の必須チェック
    describe "送信内容（request_payload）" do
      it "必須であること" do
        decomposition = build(:decomposition, request_payload: nil)
        expect(decomposition).not_to be_valid
        expect(decomposition.errors[:request_payload]).to be_present
      end
    end
  end

  # 親タスクに紐づく形で Decomposition レコードが作成できること
  describe "タスクとの関連付け（AC-1）" do
    let(:task) { create(:task) }

    it "親タスクに紐づく形で Decomposition レコードが作成・取得できること" do
      decomposition = task.decompositions.create!(
        status: :pending,
        granularity: :normal,
        request_payload: { prompt: "タスクを分解してください" }
      )

      # 分解履歴側から親タスクが参照できること
      expect(decomposition.task).to eq(task)
      # 親タスク側の一覧に作成した分解履歴が含まれていること
      expect(task.decompositions).to include(decomposition)
    end

    it "親タスクが削除されたら、紐づく分解履歴も連動して削除されること（dependent: :destroy）" do
      task.decompositions.create!(
        status: :pending,
        granularity: :normal,
        request_payload: { prompt: "タスクを分解してください" }
      )

      expect { task.destroy }.to change(described_class, :count).by(-1)
    end
  end

  # Decomposition のステータスとして pending, succeeded, failed が保存・更新できること
  describe "ステータスの enum（AC-2）" do
    let(:decomposition) { create(:decomposition) }

    it "作成直後の初期値は pending であること" do
      expect(decomposition).to be_pending
    end

    it "succeeded（成功）に更新できること" do
      decomposition.succeeded!
      expect(decomposition).to be_succeeded
      expect(decomposition.reload.status).to eq("succeeded")
    end

    it "failed（失敗）に更新できること" do
      decomposition.failed!
      expect(decomposition).to be_failed
      expect(decomposition.reload.status).to eq("failed")
    end
  end

  # 最新の分解履歴は作成日時が同じでも一意に決める（作成日時 → id の降順）
  describe ".latest_first / Task#latest_decomposition" do
    let(:task) { create(:task) }

    before { travel_to(Time.zone.local(2026, 6, 20, 10, 0)) }

    it "作成日時が同じ分解履歴は、後から作った（id が大きい）方を最新とする" do
      older = create(:decomposition, :failed, task:)
      newer = create(:decomposition, task:, status: :pending)

      expect(task.decompositions.latest_first.to_a).to eq [ newer, older ]
      expect(task.latest_decomposition).to eq newer
    end

    it "作成日時が新しい方を、id より優先して最新とする" do
      later = create(:decomposition, task:, created_at: 1.minute.from_now)
      earlier = create(:decomposition, task:, created_at: 1.minute.ago)

      expect(task.decompositions.latest_first.to_a).to eq [ later, earlier ]
      expect(task.latest_decomposition).to eq later
    end

    it "読み込み済みの関連（includes）からも同じ規則で選ぶ" do
      older = create(:decomposition, :failed, task:)
      newer = create(:decomposition, task:, status: :pending)

      loaded = Task.includes(:decompositions).find(task.id)

      expect(loaded.decompositions).to be_loaded
      expect(loaded.latest_decomposition).to eq newer
      expect(older).not_to eq newer
    end

    it "読み込み済みの関連に未保存の履歴が混ざっても例外にせず、未保存の履歴を最新とする" do
      create(:decomposition, :failed, task:)
      loaded = Task.includes(:decompositions).find(task.id)
      built = loaded.decompositions.build(status: :pending, request_payload: { prompt: "x" })

      expect(loaded.latest_decomposition).to eq built
    end

    it "分解履歴が無いときは nil" do
      expect(task.latest_decomposition).to be_nil
    end
  end

  # S-4 の見出し上と S-5 の行に出す分解ステータス（最新の分解履歴から決める）
  describe "Task#decomposition_status" do
    let(:task) { create(:task) }

    before { travel_to(Time.zone.local(2026, 6, 20, 10, 0)) }

    it "最新の分解履歴が pending なら分解中" do
      create(:decomposition, :failed, task:)
      create(:decomposition, task:, status: :pending)

      expect(task.decomposition_status).to eq :decomposing
    end

    it "最新の分解履歴が failed なら分解失敗" do
      create(:decomposition, task:, status: :pending, created_at: 1.minute.ago)
      create(:decomposition, :failed, task:)

      expect(task.decomposition_status).to eq :failed
    end

    it "最新の分解履歴が succeeded なら分解完了" do
      create(:decomposition, :succeeded, task:)

      expect(task.decomposition_status).to eq :done
    end

    it "分解履歴もサブタスクも無いときは、再分解できるよう分解失敗として扱う" do
      expect(task.decomposition_status).to eq :failed
    end

    it "分解履歴が無くてもサブタスクがあれば分解完了" do
      create(:task, :subtask, parent: task)

      expect(task.reload.decomposition_status).to eq :done
    end
  end
end
