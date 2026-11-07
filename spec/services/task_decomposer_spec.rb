require "rails_helper"

RSpec.describe TaskDecomposer do
  let(:user) { create(:user) }
  # 常に未来の日時になるよう相対日時で親タスクを作成
  let(:parent_task) { create(:task, user: user, due_at: 1.day.from_now.change(hour: 18, min: 0, sec: 0)) }
  let(:fake_client) { instance_double(Llm::FakeClient) }

  # ----------------------------------------------------------------
  # 1. 正常系の分解・保存テスト
  # ----------------------------------------------------------------
  describe "正常系: サブタスクの生成と保存" do
    let(:valid_response) do
      {
        subtasks: [
          { title: "タスク1", description: "説明1", kind: "basic", due_at: parent_task.due_at - 3.hours },
          { title: "タスク2", description: "説明2", kind: "special", due_at: parent_task.due_at - 1.hour }
        ]
      }
    end

    before do
      allow(fake_client).to receive(:decompose).and_return(valid_response)
    end

    it "外部通信なしでサブタスクが正しく保存され、Decomposition が succeeded になること" do
      decomposer = described_class.new(task: parent_task, client: fake_client)

      expect { decomposer.call }.to change { parent_task.children.count }.by(2)
      expect(decomposer.decomposition).to be_succeeded
      # children は並び順を持たず、保存時の sync_parent_status が読み直した順（DB 任せ）でメモリに残るため、
      # 作成順（id 順）で取り直して先頭を確かめる
      first_created = parent_task.children.order(:id).first
      expect(first_created.position).to eq(1)
      expect(first_created).to be_ai
    end
  end

  # ----------------------------------------------------------------
  # 2. 件数制限のバリデーションテスト
  # ----------------------------------------------------------------
  describe "件数の制御" do
    context "AI の応答が 13 件以上の場合" do
      let(:many_subtasks_response) do
        {
          subtasks: (1..15).map { |i| { title: "タスク#{i}", kind: "basic", due_at: nil } }
        }
      end

      it "先頭 12 件のみを採用して保存すること" do
        allow(fake_client).to receive(:decompose).and_return(many_subtasks_response)
        decomposer = described_class.new(task: parent_task, client: fake_client)

        expect { decomposer.call }.to change { parent_task.children.count }.by(12)
        expect(parent_task.children.pluck(:title)).to include("タスク1", "タスク12")
        expect(parent_task.children.pluck(:title)).not_to include("タスク13")
      end
    end

    context "AI の応答が 0 件の場合" do
      let(:empty_response) { { subtasks: [] } }

      it "失敗として処理され、Decomposition が failed になること" do
        allow(fake_client).to receive(:decompose).and_return(empty_response)
        decomposer = described_class.new(task: parent_task, client: fake_client)

        expect { decomposer.call }.not_to change { parent_task.children.count }
        expect(decomposer.decomposition).to be_failed
        expect(decomposer.decomposition.error_message).to include("有効なサブタスクが含まれていません")
      end
    end
  end

  # ----------------------------------------------------------------
  # 3. 期限（due_at）の丸め処理テスト
  # ----------------------------------------------------------------
  describe "期限の丸め処理" do
    let(:over_due_response) do
      {
        subtasks: [
          { title: "遅すぎるタスク", kind: "basic", due_at: (parent_task.due_at + 2.hours).iso8601 }
        ]
      }
    end

    it "親タスクの期限より後の場合、親タスクの期限に丸められること" do
      allow(fake_client).to receive(:decompose).and_return(over_due_response)
      decomposer = described_class.new(task: parent_task, client: fake_client)

      decomposer.call
      created_subtask = parent_task.children.last
      expect(created_subtask.due_at).to eq(parent_task.due_at)
    end
  end

  # ----------------------------------------------------------------
  # 4. タイトルの検証と整形テスト
  # ----------------------------------------------------------------
  describe "タイトルの整形" do
    let(:title_test_response) do
      {
        subtasks: [
          { title: "", kind: "basic", due_at: nil },
          { title: "   ", kind: "basic", due_at: nil },
          { title: "a" * 250, kind: "basic", due_at: nil }
        ]
      }
    end

    it "空タイトルの要素は除外され、200文字超は切り詰められること" do
      allow(fake_client).to receive(:decompose).and_return(title_test_response)
      decomposer = described_class.new(task: parent_task, client: fake_client)

      expect { decomposer.call }.to change { parent_task.children.count }.by(1)
      saved_subtask = parent_task.children.last
      expect(saved_subtask.title.length).to eq(200)
    end
  end
end
