require "rails_helper"

# S-4 のサブタスク一覧が 0 件のときの空状態。理由（サブタスクが 1 件も無い／選んだ日付に該当なし）で文言を出し分ける
RSpec.describe "S-4 サブタスク一覧の空状態" do
  let(:user) { create(:user) }

  before do
    travel_to(Time.zone.local(2026, 6, 20, 10, 0))
    post session_path, params: { email_address: user.email_address, password: user.password }
  end

  def empty_states(body = response.body)
    Nokogiri::HTML(body).css("[data-subtasks-empty]").to_h { [ it["data-subtasks-empty"], it ] }
  end

  context "分解に失敗してサブタスクが 1 件も無いとき" do
    let(:task) { create(:task, :decomposition_failed, user:) }

    it "「サブタスクはまだありません」と追加の案内を出し、日付タブ用の文言は出さない" do
      get task_path(task)

      state = empty_states.fetch("none")
      expect(state["hidden"]).to be_nil
      expect(state.text.squish).to include("サブタスクはまだありません", "「タスクを追加」から手順を追加できます。")
      expect(response.body).not_to include("該当するサブタスクはありません")
    end
  end

  context "サブタスクはあるが、選んだ日付に該当するものが無いとき" do
    let(:task) { create(:task, user:, due_at: 3.days.from_now) }

    before { create(:task, :subtask, parent: task, title: "明日の手順", due_at: 1.day.from_now) }

    it "日付タブの絞り込みでは「該当するサブタスクはありません」と、ほかのタブの案内を出す" do
      get task_subtasks_path(task, filter: "today"), as: :turbo_stream

      state = empty_states.fetch("filtered")
      expect(state["hidden"]).to be_nil
      expect(state.text.squish).to include("該当するサブタスクはありません", "ほかの日付か「すべて」のタブで確認できます。")
      expect(response.body).not_to include("サブタスクはまだありません")
    end

    it "「すべて」では一覧を表示し、空状態は隠す" do
      get task_path(task)

      expect(empty_states.values).to all(satisfy { it["hidden"] })
      expect(response.body).to include("明日の手順")
    end
  end
end
