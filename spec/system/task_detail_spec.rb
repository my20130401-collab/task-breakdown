require "rails_helper"

RSpec.describe "S-4 タスク詳細", :js do
  let!(:user) do
    User.create!(
      name: "詳細テスター",
      email_address: "detail_tester@example.com",
      password: "password123",
      terms_accepted_at: Time.current
    )
  end

  before do
    travel_to(Time.zone.local(2026, 6, 20, 10, 0))
    # ログインしておくことで、page.go_back で /tasks に戻っても弾かれないようにする
    visit new_session_path
    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: "password123"
    click_on "ログイン"
  end

  def card(title)
    find("ol[data-subtasks-target='list'] > li", text: title)
  end

  def check_of(title)
    find("ol [data-subtask-card-target='check'][aria-label^='「#{title}」']")
  end

  def progress_text
    find("[data-task-progress]").text.squish
  end

  def line_through?(title)
    page.evaluate_script(<<~JS)
      getComputedStyle(Array.from(document.querySelectorAll("ol [data-subtask-card-target='title']"))
        .find((el) => el.textContent.trim() === #{title.to_json})).textDecorationLine.includes("line-through")
    JS
  end

  describe "分解中からの自動遷移" do
    # 待ち時間に頼らないよう、遷移までの時間（既定 3 秒）を短く上書きしてから検証する
    def shorten_delay(milliseconds)
      page.execute_script(<<~JS)
        document.querySelector("[data-controller~='decomposition-progress']")
          .setAttribute("data-decomposition-progress-delay-value", "#{milliseconds}")
      JS
    end

    it "分解中で開くと、一定時間後に分解完了とサブタスクが表示され、戻るで分解中に戻らない" do
      visit "/tasks"
      visit "/tasks/sample?status=decomposing&title=#{CGI.escape('経費申請')}"
      expect(page).to have_css("[data-decomposition-status='decomposing']")
      expect(page).to have_css("[data-skeleton]")

      shorten_delay(100)
      expect(page).to have_css("[data-decomposition-status='done']")
      expect(page).to have_text("目的と読み手を整理する")
      expect(page).to have_css("h1", text: "経費申請")
      expect(page).to have_no_css("[data-skeleton]")

      page.go_back
      expect(page).to have_current_path("/tasks")
    end

    it "autoplay=0 では、遷移までの時間を過ぎても分解中のまま遷移しない" do
      visit "/tasks/sample?status=decomposing&autoplay=0"
      expect(page).to have_css("[data-decomposition-status='decomposing']")

      shorten_delay(50)
      sleep 0.5
      expect(page).to have_css("[data-decomposition-status='decomposing']")
      expect(page).to have_current_path("/tasks/sample?status=decomposing&autoplay=0")
    end
  end

  describe "親タスクのメニュー" do
    let(:trigger) { find("button[aria-controls='task-menu']") }

    def focused_item
      page.evaluate_script("document.activeElement.textContent").strip
    end

    before do
      visit "/tasks/sample"
    end

    it "開くと最初の項目にフォーカスし、↑↓・Home・End で項目を移動できる" do
      trigger.click
      expect(page).to have_css("#task-menu [role='menuitem']:focus", text: "編集")

      page.send_keys(:down)
      expect(focused_item).to eq "再分解"
      page.send_keys(:end)
      expect(focused_item).to eq "削除"
      page.send_keys(:down)
      expect(focused_item).to eq "編集"
      page.send_keys(:up)
      expect(focused_item).to eq "削除"
      page.send_keys(:home)
      expect(focused_item).to eq "編集"
    end

    it "Esc で閉じてトリガーにフォーカスが戻る" do
      trigger.click
      expect(page).to have_css("#task-menu", visible: true)

      page.send_keys(:escape)
      expect(page).to have_no_css("#task-menu", visible: true)
      expect(trigger["aria-expanded"]).to eq "false"
      expect(page).to have_css("button[aria-controls='task-menu']:focus")
    end

    it "外側のクリックで閉じる" do
      trigger.click
      expect(page).to have_css("#task-menu", visible: true)

      find("h1").click
      expect(page).to have_no_css("#task-menu", visible: true)
    end

    it "Tab でメニューの外へフォーカスが出ると閉じる" do
      trigger.click
      expect(page).to have_css("#task-menu [role='menuitem']:focus")

      page.send_keys(:tab)
      expect(page).to have_no_css("#task-menu", visible: true)
      expect(trigger["aria-expanded"]).to eq "false"
    end

    it "見た目のみの項目を押すと何も起きずに閉じる" do
      trigger.click
      find("#task-menu [role='menuitem']", text: "再分解").click

      expect(page).to have_no_css("#task-menu", visible: true)
      expect(page).to have_current_path("/tasks/sample")
      expect(page).to have_css("button[aria-controls='task-menu']:focus")
    end
  end

  describe "タスクを追加" do
    def added_title
      find("ol > li:last-child [data-subtask-card-target='title'][contenteditable='true']")
    end

    def added_description
      find("ol > li:last-child [data-subtask-card-target='description'][contenteditable='true']")
    end

    it "3 回追加すると番号が続き、id が重複せず、追加カードのメニューも開ける" do
      visit "/tasks/sample"

      3.times { click_on "タスクを追加" }

      numbers = all("ol [data-subtask-number]", visible: :all).map { it.text(:all).strip }
      expect(numbers).to eq %w[01 02 03 04 05 06 07 08 09]
      ids = page.evaluate_script("Array.from(document.querySelectorAll('[id]')).map((el) => el.id)")
      expect(ids).to eq ids.uniq
      expect(ids).to include("subtask-menu-07", "subtask-menu-08", "subtask-menu-09")
      expect(page).to have_no_css("ol [id*='__NUMBER__']", visible: :all)

      find("button[aria-controls='subtask-menu-09']").click
      expect(page).to have_css("#subtask-menu-09 [role='menuitem']", text: "期限設定")
      expect(progress_text).to eq "1/9 完了"
    end

    it "追加直後にタスク名へフォーカスし、入力したタスク名を完了チェックとメニューの読み上げに反映する" do
      visit "/tasks/sample"
      click_on "タスクを追加"

      expect(page).to have_css("ol > li:last-child [data-subtask-card-target='title']:focus")
      expect(added_title["data-placeholder"]).to eq "タスク名を入力"
      expect(check_of("新しいタスク")["aria-label"]).to eq "「新しいタスク」を完了にする"
      expect(page).to have_css("button[aria-controls='subtask-menu-07'][aria-label='「新しいタスク」のメニュー']")

      page.send_keys("見積もりを依頼する")
      expect(added_title.text).to eq "見積もりを依頼する"
      expect(check_of("見積もりを依頼する")["aria-label"]).to eq "「見積もりを依頼する」を完了にする"
      expect(page).to have_css("button[aria-controls='subtask-menu-07'][aria-label='「見積もりを依頼する」のメニュー']")

      # Enter は改行せず補足の入力へ移る
      page.send_keys(:enter)
      expect(added_title.text).to eq "見積もりを依頼する"
      expect(page).to have_css("ol > li:last-child [data-subtask-card-target='description']:focus")
      page.send_keys("仕入れ先 2 社に依頼する")
      expect(added_description.text).to eq "仕入れ先 2 社に依頼する"

      # 完了にすると入力したタスク名で「未完了に戻す」になる
      click_on "完了済みを表示"
      check_of("見積もりを依頼する").click
      expect(check_of("見積もりを依頼する")["aria-label"]).to eq "「見積もりを依頼する」を未完了に戻す"
      expect(line_through?("見積もりを依頼する")).to be true
    end

    it "タスク名を消すと、プレースホルダが出て読み上げ名も「新しいタスク」に戻る" do
      visit "/tasks/sample"
      click_on "タスクを追加"

      page.send_keys("仮の名前")
      expect(check_of("仮の名前")).to be_present
      4.times { page.send_keys(:backspace) }

      expect(page.evaluate_script("document.querySelector(\"ol > li:last-child [data-subtask-card-target='title']\").matches(':empty')")).to be true
      expect(check_of("新しいタスク")["aria-label"]).to eq "「新しいタスク」を完了にする"
    end

    it "貼り付けは書式を落としたテキストだけを入れ、タスク名では改行を空白にする" do
      visit "/tasks/sample"
      click_on "タスクを追加"

      paste = lambda do |target, plain|
        page.execute_script(<<~JS, target, plain)
          const field = document.querySelector(`ol > li:last-child [data-subtask-card-target='${arguments[0]}']`)
          field.focus()
          const data = new DataTransfer()
          data.setData("text/html", "<b>太字</b><div>別の行</div>")
          data.setData("text/plain", arguments[1])
          field.dispatchEvent(new ClipboardEvent("paste", { clipboardData: data, bubbles: true, cancelable: true }))
        JS
      end

      paste.call("title", "見積もりを\n依頼する")
      expect(added_title.text).to eq "見積もりを 依頼する"
      expect(page.evaluate_script("document.querySelector(\"ol > li:last-child [data-subtask-card-target='title']\").innerHTML"))
        .to eq "見積もりを 依頼する"
      expect(check_of("見積もりを 依頼する")["aria-label"]).to eq "「見積もりを 依頼する」を完了にする"

      paste.call("description", "1 行目\n2 行目")
      expect(page.evaluate_script("document.querySelector(\"ol > li:last-child [data-subtask-card-target='description']\").innerHTML"))
        .to eq "1 行目\n2 行目"
    end

    it "既存のカードのタスク名は編集できない" do
      visit "/tasks/sample"

      expect(page).to have_no_css("ol > li:not(:last-child) [contenteditable]")
      expect(all("ol [contenteditable]")).to be_empty
    end

    it "分解失敗の画面でも追加でき、進捗が「—」から n/m 完了に変わる" do
      visit "/tasks/sample?status=failed"
      expect(progress_text).to eq "—"

      click_on "タスクを追加"
      expect(page).to have_css("ol [data-subtask-number]", text: "01")
      expect(progress_text).to eq "0/1 完了"
      expect(page).to have_css("[data-task-progress][role='progressbar'][aria-valuemax='1']")
    end
  end

  describe "完了チェック" do
    it "完了にすると消え、表示すると打ち消し線付きで現れ、未完了に戻せる（進捗も連動する）" do
      visit "/tasks/sample"
      expect(progress_text).to eq "1/6 完了"

      check_of("目的と読み手を整理する").click
      expect(page).to have_no_text("目的と読み手を整理する")
      expect(progress_text).to eq "2/6 完了"
      expect(page).to have_css("[data-task-progress][aria-valuenow='2'][aria-valuemax='6']")
      # 消えたカードの代わりに次の完了チェックへフォーカスが移る
      expect(page).to have_css("[data-subtask-card-target='check'][aria-label^='「必要な情報を集める」']:focus")

      click_on "完了済みを表示"
      expect(card("目的と読み手を整理する")["data-done"]).to eq "true"
      expect(line_through?("目的と読み手を整理する")).to be true
      expect(check_of("目的と読み手を整理する")["aria-label"]).to eq "「目的と読み手を整理する」を未完了に戻す"

      check_of("目的と読み手を整理する").click
      expect(card("目的と読み手を整理する")["data-done"]).to eq "false"
      expect(line_through?("目的と読み手を整理する")).to be false
      expect(check_of("目的と読み手を整理する")["aria-label"]).to eq "「目的と読み手を整理する」を完了にする"
      expect(progress_text).to eq "1/6 完了"

      numbers = all("ol [data-subtask-number]").map { it.text.strip }
      expect(numbers).to eq %w[01 02 03 04 05 06]
    end

    it "最初から完了済みのカードも打ち消し線付きで表示され、1 回のクリックで未完了に戻る" do
      visit "/tasks/sample"
      click_on "完了済みを表示"

      title = "依頼の背景と締め切りを確認する"
      expect(line_through?(title)).to be true
      expect(check_of(title)["aria-label"]).to eq "「#{title}」を未完了に戻す"

      check_of(title).click
      expect(line_through?(title)).to be false
      expect(check_of(title)["aria-label"]).to eq "「#{title}」を完了にする"

      click_on "完了済みを隠す"
      expect(page).to have_text(title)
    end

    it "すべて完了にすると全完了の空状態が出て、完了済みを表示すると消える" do
      visit "/tasks/sample"
      expect(page).to have_no_text("すべての手順が完了しました")

      %w[目的と読み手を整理する 必要な情報を集める 上長に方向性を確認する 初稿を作成する 提出後に振り返りをメモする].each do |title|
        check_of(title).click
        expect(page).to have_no_text(title)
      end

      expect(page).to have_text("すべての手順が完了しました")
      expect(page).to have_link("マイタスクへ", href: "/tasks")
      expect(progress_text).to eq "6/6 完了"

      click_on "完了済みを表示"
      expect(page).to have_no_text("すべての手順が完了しました")
      expect(page).to have_text("初稿を作成する")
    end

    it "all_done=1 では最初から全完了の空状態を表示する" do
      visit "/tasks/sample?status=done&all_done=1"

      expect(page).to have_text("すべての手順が完了しました")
      expect(progress_text).to eq "6/6 完了"
    end
  end

  describe "日付タブ" do
    def tab(label)
      find("[role='tablist'] [role='tab']", text: label, exact_text: true)
    end

    def visible_titles
      all("ol > li [data-subtask-card-target='title']").map { it.text.strip }
    end

    def selected_tab
      find("[role='tab'][aria-selected='true']").text.strip
    end

    let(:tab_empty) { "この日のサブタスクはありません" }

    it "「今日」で今日の手順だけを表示し、「すべて」で戻る。選んだタブに下線が付く" do
      visit "/tasks/sample"
      expect(visible_titles.size).to eq 5

      tab("今日").click
      expect(visible_titles).to eq %w[目的と読み手を整理する 必要な情報を集める]
      expect(tab("今日")["aria-selected"]).to eq "true"
      expect(tab("すべて")["aria-selected"]).to eq "false"
      expect(find("[role='tabpanel']")["aria-labelledby"]).to eq "date-tab-today"
      underline = ->(label) { page.evaluate_script("getComputedStyle(document.getElementById('date-tab-#{label}')).borderBottomColor") }
      expect(underline.call("today")).not_to eq underline.call("all")
      expect(underline.call("all")).to eq "rgba(0, 0, 0, 0)"

      tab("すべて").click
      expect(visible_titles.size).to eq 5
      expect(visible_titles.last).to eq "提出後に振り返りをメモする"
    end

    it "期限なしの手順は「すべて」にだけ表示する" do
      visit "/tasks/sample"

      %w[今日 明日 6/27].each do |label|
        tab(label).click
        expect(page).to have_no_text("提出後に振り返りをメモする")
      end
      tab("すべて").click
      expect(page).to have_text("提出後に振り返りをメモする")
    end

    it "完了フィルタと独立して働き、どちらにも隠されていない手順だけを表示する" do
      visit "/tasks/sample"

      tab("今日").click
      expect(page).to have_no_text("依頼の背景と締め切りを確認する")
      click_on "完了済みを表示"
      expect(visible_titles).to eq %w[依頼の背景と締め切りを確認する 目的と読み手を整理する 必要な情報を集める]

      tab("明日").click
      expect(visible_titles).to eq %w[上長に方向性を確認する]
    end

    it "「明日」で完了済みを隠した結果 0 件になると、タブの空状態だけを出し、全完了の文言は出さない" do
      visit "/tasks/sample"
      tab("明日").click
      expect(page).to have_no_text(tab_empty)

      check_of("上長に方向性を確認する").click
      expect(page).to have_no_text("上長に方向性を確認する")
      expect(page).to have_text(tab_empty)
      expect(page).to have_no_text("すべての手順が完了しました")

      click_on "完了済みを表示"
      expect(page).to have_no_text(tab_empty)
      expect(page).to have_text("上長に方向性を確認する")

      click_on "完了済みを隠す"
      expect(page).to have_text(tab_empty)
      tab("すべて").click
      expect(page).to have_no_text(tab_empty)
    end

    it "全サブタスクが完了済みのときは、どのタブでも全完了の空状態だけを出す" do
      visit "/tasks/sample?status=done&all_done=1"
      expect(page).to have_text("すべての手順が完了しました")

      tab("明日").click
      expect(page).to have_text("すべての手順が完了しました")
      expect(page).to have_no_text(tab_empty)
    end

    it "←→ でタブを移動して選び、Home・End で先頭・末尾へ移る。Tab キーは選択中のタブだけに止まる" do
      visit "/tasks/sample"
      tab("すべて").click
      expect(page).to have_css("#date-tab-all:focus")

      page.send_keys(:right)
      expect(page).to have_css("#date-tab-today:focus")
      expect(selected_tab).to eq "今日"
      expect(visible_titles).to eq %w[目的と読み手を整理する 必要な情報を集める]

      page.send_keys(:right)
      expect(selected_tab).to eq "明日"
      page.send_keys(:end)
      expect(selected_tab).to eq "6/27"
      expect(visible_titles).to eq %w[初稿を作成する]
      page.send_keys(:right)
      expect(selected_tab).to eq "すべて"
      page.send_keys(:left)
      expect(selected_tab).to eq "6/27"
      page.send_keys(:home)
      expect(selected_tab).to eq "すべて"
      expect(page).to have_css("#date-tab-all:focus")

      tabindexes = all("[role='tab']").map { it["tabindex"] }
      expect(tabindexes).to eq %w[0 -1 -1 -1]
    end

    it "修飾キー付きの ←→（Alt+← の「戻る」など）はブラウザの操作に任せ、タブを動かさない" do
      visit "/tasks/sample"
      tab("すべて").click

      %i[alt control meta shift].each do |modifier|
        page.send_keys([ modifier, :right ])
        expect(selected_tab).to eq "すべて"
      end
      expect(page.evaluate_script(<<~JS)).to be false
        (() => {
          const event = new KeyboardEvent("keydown", { key: "ArrowLeft", altKey: true, bubbles: true, cancelable: true })
          document.getElementById("date-tab-all").dispatchEvent(event)
          return event.defaultPrevented
        })()
      JS
    end

    it "タスクを追加すると「すべて」に戻り、追加したカード（期限は今日）が見える" do
      visit "/tasks/sample"
      tab("明日").click

      click_on "タスクを追加"
      expect(selected_tab).to eq "すべて"
      expect(visible_titles.size).to eq 6
      expect(page).to have_css("ol > li:last-child[data-due-key='today']")
      expect(page).to have_css("ol > li:last-child [data-subtask-card-target='title']:focus")

      tab("今日").click
      expect(page).to have_css("ol > li:last-child [data-subtask-card-target='title']", visible: true)
    end

    it "タブで隠れた手順も親タスクの進捗に数える" do
      visit "/tasks/sample"
      tab("明日").click

      expect(progress_text).to eq "1/6 完了"
      check_of("上長に方向性を確認する").click
      expect(progress_text).to eq "2/6 完了"
    end
  end
end
