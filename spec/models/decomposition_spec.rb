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
end
