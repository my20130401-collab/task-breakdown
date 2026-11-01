require "rails_helper"

RSpec.describe "共通部品", :js do
  before do
    travel_to(Time.zone.local(2026, 6, 20, 10, 0))
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
      visit "/tasks/sample"
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
    it "S-4 でも完了済みのサブタスクが初期非表示で、トグルで現れる" do
      visit "/tasks/sample"

      expect(page).to have_no_text("依頼の背景と締め切りを確認する")
      click_on "完了済みを表示"
      expect(page).to have_text("依頼の背景と締め切りを確認する")
      click_on "完了済みを隠す"
      expect(page).to have_no_text("依頼の背景と締め切りを確認する")
    end

    it "後から完了になった要素も隠し、表示対象が 0 件になると空状態を出す" do
      visit "/tasks/sample"
      # 空状態の置き場所は各画面で決めるため、ここではラッパー内に差し込んで部品の振る舞いだけを確かめる
      page.execute_script(<<~JS)
        const empty = document.createElement("p")
        empty.dataset.completedFilterTarget = "empty"
        empty.hidden = true
        empty.textContent = "表示できる手順はありません"
        document.querySelector("[data-controller~='completed-filter']").append(empty)
      JS
      expect(page).to have_no_text("表示できる手順はありません")

      page.execute_script(<<~JS)
        document.querySelectorAll("ol [data-done]").forEach((el) => { el.dataset.done = "true" })
      JS
      expect(page).to have_no_text("目的と読み手を整理する")
      expect(page).to have_text("表示できる手順はありません")

      click_on "完了済みを表示"
      expect(page).to have_text("目的と読み手を整理する")
      expect(page).to have_no_text("表示できる手順はありません")
    end
  end
end
