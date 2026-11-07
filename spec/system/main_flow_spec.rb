require "rails_helper"

# 主要導線: 会員登録 → タスク作成 → AI 分解 → サブタスク完了 → ログアウトを画面操作だけで通す。
# 分解はジョブで動く。test 環境の ActiveJob は test アダプタ（積むだけで実行しない）、Action Cable も test アダプタで
# ブラウザへは配信されないため、perform_enqueued_jobs で実行してから再読み込みして結果を見る。
# LLM は Llm::Client.build がキー無しで選ぶ Llm::FakeClient（固定 3 件。期限は現在時刻の 1 時間後から）
RSpec.describe "主要導線", :js do
  include ActiveJob::TestHelper

  before { travel_to(Time.zone.local(2026, 6, 20, 10, 0)) }

  def register(name:)
    visit new_registration_path
    fill_in "お名前", with: name
    fill_in "メールアドレス", with: "main-flow@example.com"
    fill_in "パスワード", with: "password123"
    fill_in "パスワード（確認）", with: "password123"
    check "利用規約とプライバシーポリシーに同意する"
    click_on "アカウントを作成する"
    expect(page).to have_current_path(root_path)
  end

  def create_task(title:, due:)
    find("textarea[aria-label='取り組みたいこと']").fill_in(with: title)
    fill_in "期限（任意）", with: due
    click_on "タスクを分解する"
    expect(page).to have_current_path(%r{\A/tasks/\d+\z})
  end

  def subtask_cards
    all("ol [data-done]")
  end

  it "会員登録からサブタスクの完了まで進め、ログアウトできる" do
    register(name: "新入 一郎")
    within("aside") { expect(page).to have_content("新入 一郎") }

    create_task(title: "取引先への見積書を提出する", due: "2026-06-21T18:00")
    expect(page).to have_css("[data-decomposition-status='decomposing']", text: "分解中")

    perform_enqueued_jobs
    refresh

    expect(page).to have_css("[data-decomposition-status='done']", text: "分解完了")
    expect(subtask_cards.size).to eq 3
    expect(page).to have_css("ol span", text: "特殊", count: 1)

    find("ol [data-subtask-card-target='check'][aria-label='「仕入れ先に見積もりを依頼する」を完了にする']").click
    expect(page).to have_css("[data-task-progress-text]", text: "1/3 完了")

    within("aside") { click_on "マイタスク" }
    within(find("li", text: "取引先への見積書を提出する")) { expect(page).to have_content("1/3 完了") }

    within("aside") do
      find("button[aria-controls='user-menu']").click
      click_on "ログアウト"
    end
    expect(page).to have_current_path(new_session_path)
  end

  it "AI の応答が 0 件だと分解に失敗し、再分解すると分解中に戻る" do
    fake = Llm::FakeClient.new
    allow(fake).to receive(:decompose).and_return(subtasks: [])
    allow(Llm::FakeClient).to receive(:new).and_return(fake)

    register(name: "新入 二郎")
    create_task(title: "部署の歓迎会を企画する", due: "2026-06-27T18:00")

    perform_enqueued_jobs
    refresh

    expect(page).to have_css("[data-decomposition-status='failed']", text: "分解失敗")
    expect(page).to have_content("分解に失敗しました")

    # 時刻を止めたままだと新旧の分解履歴の created_at が同じになり、S-4 がどちらを最新と見るか定まらない
    travel 1.minute
    click_on "再分解する"
    expect(page).to have_css("[data-decomposition-status='decomposing']", text: "分解中")
    expect(enqueued_jobs.size).to eq 1
  end
end
