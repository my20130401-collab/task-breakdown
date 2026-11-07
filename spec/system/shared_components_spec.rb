# frozen_string_literal: true

require "rails_helper"

RSpec.describe "共通部品", :js do
  let!(:user) do
    User.create!(
      name: "テストユーザー",
      email_address: "shared_test@example.com",
      password: "password123",
      terms_accepted_at: Time.current
    )
  end

  before do
    travel_to(Time.zone.local(2026, 6, 20, 10, 0))
    # ログインしてマイタスク一覧（S-5）へ移動
    visit new_session_path
    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: "password123"
    click_on "ログイン"
  end

  describe "ユーザーメニュー" do
    # 項目が aside の内側かつ画面内にあり、他の要素に隠れていないか
    def menuitem_placement
      page.evaluate_script(<<~JS)
        (() => {
          const r = document.querySelector("aside [role='menuitem']").getBoundingClientRect()
          const aside = document.querySelector("aside").getBoundingClientRect()
          const hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2)
          return { inViewport: r.top >= 0 && r.bottom <= window.innerHeight,
                   inAside: r.left >= aside.left && r.right <= aside.right,
                   onTop: hit !== null && hit.closest("[role='menuitem']") !== null }
        })()
      JS
    end

    let(:trigger) { find("aside button[aria-haspopup='menu']") }

    before do
      visit tasks_path
    end

    it "開くと項目が画面内に見え、最初の項目にフォーカスが移る" do
      expect(trigger["aria-expanded"]).to eq "false"
      expect(page).to have_no_css("aside [role='menuitem']", visible: true)

      trigger.click

      expect(trigger["aria-expanded"]).to eq "true"
      expect(find("aside [role='menuitem']", text: "ログアウト")).to be_visible
      expect(page).to have_css("aside [role='menuitem']:focus", text: "ログアウト")
      expect(menuitem_placement).to eq("inViewport" => true, "inAside" => true, "onTop" => true)
    end

    it "Esc で閉じてトリガーにフォーカスが戻る" do
      trigger.click
      expect(page).to have_css("aside [role='menuitem']", visible: true)

      page.send_keys(:escape)

      expect(page).to have_no_css("aside [role='menuitem']", visible: true)
      expect(trigger["aria-expanded"]).to eq "false"
      expect(page).to have_css("aside button[aria-haspopup='menu']:focus")
    end

    it "ログアウトでログイン画面へ移る" do
      trigger.click
      find("aside [role='menuitem']", text: "ログアウト").click

      expect(page).to have_current_path("/session/new")
      expect(page).to have_content("おかえりなさい")
    end

    it "メニューの外側をクリックすると閉じる" do
      trigger.click
      expect(page).to have_css("aside [role='menuitem']", visible: true)

      find("h1").click
      expect(page).to have_no_css("aside [role='menuitem']", visible: true)
      expect(trigger["aria-expanded"]).to eq "false"
    end
  end

  describe "完了フィルタ" do
    let!(:task) { user.tasks.create!(title: "完了済みの親タスク", due_at: 1.day.from_now) }

    before do
      # サブタスクをすべて完了にし、親タスクを全完了状態にする
      task.children.create!(user: user, title: "完了サブタスク", status: :done)
      visit tasks_path
    end

    it "完了済みの親タスクが初期非表示で、トグルで現れる" do
      expect(page).to have_no_text("完了済みの親タスク")

      click_on "完了済みを表示"
      expect(page).to have_text("完了済みの親タスク")

      click_on "完了済みを隠す"
      expect(page).to have_no_text("完了済みの親タスク")
    end
  end
end
