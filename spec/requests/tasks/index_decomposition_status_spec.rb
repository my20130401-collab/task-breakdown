require "rails_helper"

# S-5 マイタスクの行の分解ステータス。分解中・分解失敗の行にだけ出す（分解完了は出さない）
RSpec.describe "S-5 行の分解ステータス" do
  let(:user) { create(:user) }

  before do
    travel_to(Time.zone.local(2026, 6, 20, 10, 0))
    post session_path, params: { email_address: user.email_address, password: user.password }
    create(:task, :decomposing, user:, title: "週報を書く")
    create(:task, :decomposition_failed, user:, title: "歓迎会を企画する")
    create(:task, :decomposed, user:, title: "見積書を提出する")
  end

  def row_statuses
    Nokogiri::HTML(response.body).css("li[data-done]").to_h do |row|
      [ row.at_css("a p").text.squish, row.at_css("[data-decomposition-status]")&.then { [ it["data-decomposition-status"], it.text.squish ] } ]
    end
  end

  it "分解中は「分解中」、分解失敗は「分解失敗」を出し、分解完了の行には出さない" do
    get tasks_path

    expect(row_statuses).to eq(
      "週報を書く" => %w[decomposing 分解中],
      "歓迎会を企画する" => %w[failed 分解失敗],
      "見積書を提出する" => nil
    )
  end

  it "再分解で最新の分解履歴が分解中になったら、失敗の行も分解中として出す" do
    failed = user.tasks.find_by!(title: "歓迎会を企画する")
    create(:decomposition, task: failed, status: :pending)

    get tasks_path

    expect(row_statuses["歓迎会を企画する"]).to eq %w[decomposing 分解中]
  end

  it "行の数に関わらず、分解履歴の読み込みでクエリが増えない" do
    get tasks_path
    baseline = count_queries { get tasks_path }

    create(:task, :decomposition_failed, user:, title: "追加の失敗タスク")
    create(:task, :decomposing, user:, title: "追加の分解中タスク")

    expect(count_queries { get tasks_path }).to eq baseline
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end
end
