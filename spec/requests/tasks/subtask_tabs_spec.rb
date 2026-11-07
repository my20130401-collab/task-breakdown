require "rails_helper"

# S-4 の日付タブ。サーバ側で絞り込むリンクの並びなので、タブ（role=tablist）ではなくナビゲーションとして表し、
# 選んでいるタブを aria-current で伝える
RSpec.describe "S-4 日付タブ" do
  let(:user) { create(:user) }
  let(:task) { create(:task, user:, due_at: 5.days.from_now) }

  before do
    travel_to(Time.zone.local(2026, 6, 20, 10, 0))
    post session_path, params: { email_address: user.email_address, password: user.password }
    create(:task, :subtask, parent: task, title: "今日の手順", due_at: Time.current.change(hour: 17))
    create(:task, :subtask, parent: task, title: "3 日後の手順", due_at: 3.days.from_now)
  end

  def tabs(body = response.body)
    Nokogiri::HTML(body).at_css("#subtask_tabs")
  end

  def current_tabs(body = response.body)
    tabs(body).css("a[aria-current]").map { [ it.text.squish, it["aria-current"] ] }
  end

  it "日付で絞り込むナビゲーションとして名前を持ち、tablist を名乗らない" do
    get task_path(task)

    expect(tabs.name).to eq "nav"
    expect(tabs["aria-label"]).to eq "日付で絞り込む"
    expect(tabs["role"]).to be_nil
    expect(tabs.css("a").map { it.text.squish }).to eq %w[すべて 今日 明日 6/23]
  end

  it "最初は「すべて」だけが aria-current を持つ" do
    get task_path(task)

    expect(current_tabs).to eq [ %w[すべて true] ]
  end

  it "タブを選ぶと、選んだタブだけが aria-current を持つ" do
    get task_subtasks_path(task, filter: "today"), as: :turbo_stream
    expect(current_tabs).to eq [ %w[今日 true] ]

    get task_subtasks_path(task, filter: "2026-06-23"), as: :turbo_stream
    expect(current_tabs).to eq [ %w[6/23 true] ]
  end
end
