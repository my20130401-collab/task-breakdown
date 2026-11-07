require "rails_helper"

# サイドバーの現在地（aria-current）。タスク詳細（S-4）・タスクの編集（S-8）はマイタスクの配下として扱う
RSpec.describe "サイドバーの現在地" do
  let!(:user) do
    User.create!(
      name: "サイドバー確認ユーザー",
      email_address: "sidebar@example.com",
      password: "password123",
      terms_accepted_at: Time.current
    )
  end
  let!(:task) { user.tasks.create!(title: "見積もりを作成する") }

  before do
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  def nav_current
    Nokogiri::HTML(response.body).css("aside nav a").to_h { [ it.text.squish, it["aria-current"] ] }
  end

  it "タスクを作る（S-3）では「タスクを作る」が現在の画面" do
    get root_path

    expect(nav_current).to eq("タスクを作る" => "page", "マイタスク" => nil)
  end

  it "マイタスク（S-5）では「マイタスク」が現在の画面" do
    get tasks_path

    expect(nav_current).to eq("タスクを作る" => nil, "マイタスク" => "page")
  end

  it "タスク詳細（S-4）では「マイタスク」を配下としてハイライトする" do
    get task_path(task)

    expect(nav_current).to eq("タスクを作る" => nil, "マイタスク" => "true")
  end

  it "タスクの編集（S-8）では「マイタスク」を配下としてハイライトする" do
    get edit_task_path(task)

    expect(nav_current).to eq("タスクを作る" => nil, "マイタスク" => "true")
  end

  it "作成画面を入力エラーで描き直したときも「タスクを作る」をハイライトする" do
    post tasks_path, params: { task: { title: "" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(nav_current).to eq("タスクを作る" => "true", "マイタスク" => nil)
  end
end
