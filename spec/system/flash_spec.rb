require "rails_helper"

# 保存・削除などの結果のお知らせ（flash）。ヘッダーバーに重ならない位置に出し、閉じられ、一定時間で消える
RSpec.describe "お知らせ（flash）", :js do
  let!(:user) { create(:user) }

  before do
    travel_to(Time.zone.local(2026, 6, 20, 10, 0))
    visit new_session_path
    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: user.password
    click_on "ログイン"
    page.assert_current_path(root_path)

    find("textarea[aria-label='取り組みたいこと']").fill_in(with: "取引先への見積書を提出する")
    click_on "タスクを分解する"
    page.assert_current_path(%r{\A/tasks/\d+\z})
  end

  def notice
    find("[data-controller='flash'][role='status']", text: "タスクを作成しました")
  end

  def rect_of(selector)
    page.evaluate_script(<<~JS)
      (() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect();
               return { top: r.top, bottom: r.bottom, left: r.left, right: r.right } })()
    JS
  end

  it "タスク詳細のヘッダーバーと重ならない位置に表示する" do
    expect(notice).to be_visible

    header = rect_of("header")
    toast = rect_of("[data-controller='flash']")
    overlap = toast["top"] < header["bottom"] && toast["bottom"] > header["top"] &&
              toast["left"] < header["right"] && toast["right"] > header["left"]

    expect(overlap).to be(false), "お知らせ #{toast} がヘッダー #{header} に重なっています"
    expect(toast["top"]).to be >= header["bottom"]
  end

  it "閉じるボタンで消せる" do
    within(notice) { click_on "お知らせを閉じる" }

    expect(page).to have_no_text("タスクを作成しました")
  end

  it "一定時間で自動的に消える（待ち時間は data-flash-timeout-value）" do
    expect(notice["data-flash-timeout-value"]).to eq "5000"

    # 待ち時間を短く上書きして、時間で消えることを確かめる
    page.execute_script(<<~JS)
      document.querySelector("[data-controller='flash']").setAttribute("data-flash-timeout-value", "50")
    JS

    expect(page).to have_no_text("タスクを作成しました")
  end
end
