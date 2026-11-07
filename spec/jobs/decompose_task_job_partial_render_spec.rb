require "rails_helper"

# ジョブからの配信はコントローラの外で partial を描画するため、@task などのインスタンス変数に頼ると落ちる。
# スタブせずに実際に描画して、配信用の partial がジョブから描けることを確認する
RSpec.describe DecomposeTaskJob do
  describe "配信する partial の描画" do
    let(:user) { create(:user) }
    let(:task) { create(:task, user: user) }

    before { create(:decomposition, task: task, status: :pending) }

    it "分解に成功したとき、サブタスク一覧・分解ステータス・進捗を描画して配信できる" do
      allow(Llm::Client).to receive(:build).and_return(Llm::FakeClient.new)

      expect { described_class.perform_now(task.id) }.not_to raise_error
      expect(task.children.count).to eq Llm::FakeClient::DEFAULT_RESPONSE[:subtasks].size
    end

    it "分解に失敗したとき、失敗画面（手動追加の導線つき）を描画して配信できる" do
      client = instance_double(Llm::FakeClient, decompose: { subtasks: [] })
      allow(Llm::Client).to receive(:build).and_return(client)

      expect { described_class.perform_now(task.id) }.not_to raise_error
      expect(task.decompositions.order(:created_at).last).to be_failed
    end
  end
end
