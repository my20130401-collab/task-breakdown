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
   let!(:parent_task) { user.tasks.create!(title: "親タスク", due_at: 1.day.from_now) }

    before do
      # 準備: 今日、明日、期限なしのタスクと、補足説明（AC-2）を持つタスクを作成
      parent_task.children.create!(user: user, title: "今日のタスク", due_at: Time.current)
      parent_task.children.create!(user: user, title: "明日のタスク", due_at: Time.current.tomorrow)
      parent_task.children.create!(user: user, title: "期限なしタスク", due_at: nil)
      parent_task.children.create!(user: user, title: "補足付きタスク", due_at: Time.current, description: "これは補足説明のテストです")

      # モックではなく実際の詳細画面へ遷移
      visit task_path(parent_task)
    end

    it "タブをクリックすると画面リロードなしでサブタスクが絞り込まれ、補足説明も表示されること" do
      # 初期表示（すべてタブ）
      expect(page).to have_content "今日のタスク"
      expect(page).to have_content "明日のタスク"
      expect(page).to have_content "期限なしタスク"
      expect(page).to have_content "これは補足説明のテストです"

      # 「今日」タブをクリック（Turbo Streamの非同期更新）
      click_link "今日"
      expect(page).to have_content "今日のタスク"
      expect(page).to have_content "補足付きタスク"
      expect(page).not_to have_content "明日のタスク"
      expect(page).not_to have_content "期限なしタスク"

      # 「明日」タブをクリック
      click_link "明日"
      expect(page).not_to have_content "今日のタスク"
      expect(page).to have_content "明日のタスク"
      expect(page).not_to have_content "期限なしタスク"
    end
  end


  describe "サブタスクの追加・編集・削除 (UC-3)" do
    let!(:parent_task) { user.tasks.create!(title: "親タスク", due_at: 1.day.from_now) }
    let!(:existing_subtask) { parent_task.children.create!(user: user, title: "既存のサブタスク") }

    before do
      visit task_path(parent_task)
    end

    it "AC-1, AC-2: 「タスクを追加」からインラインでタスクを作成できる" do
      click_link "タスクを追加"

      # フォームが末尾に追加されることを確認
      expect(page).to have_css("li#new_subtask_form")

      within("li#new_subtask_form") do
        fill_in "サブタスク名", with: "新しいテストサブタスク"
        fill_in "補足説明（任意）", with: "テストの補足"
        click_button "保存"
      end

      # フォームが消え、タスクとしてリストに追加されることを確認
      expect(page).to have_no_css("li#new_subtask_form")
      expect(page).to have_content("新しいテストサブタスク")
      expect(page).to have_content("テストの補足")
      # 既存サブタスクの次の番号（02）が振られることを確認
      expect(page).to have_css("span", text: "02")
    end

    it "AC-3: 既存のサブタスクをインラインで編集できる" do
      # メニューを開いて「編集」をクリック
      find("button[aria-controls='subtask-menu-#{existing_subtask.id}']").click
      click_link "編集"

      # Subtask(Task) モデルなので dom_id は task_xx になる
      within("li#task_#{existing_subtask.id}") do
        fill_in "サブタスク名", with: "更新されたサブタスク"
        click_button "保存"
      end

      # フォームが閉じ、更新後のタイトルが表示されることを確認
      expect(page).to have_no_field("サブタスク名")
      expect(page).to have_content("更新されたサブタスク")
    end

    it "AC-4: サブタスクを削除できる" do
      expect(page).to have_content("既存のサブタスク")

      # メニューを開いて「削除」をクリックし、ダイアログを承認
      find("button[aria-controls='subtask-menu-#{existing_subtask.id}']").click
      accept_confirm "本当に削除しますか？" do
        click_link "削除"
      end

      # リロードなしで画面から消えることを確認
      expect(page).to have_no_content("既存のサブタスク")
    end
  end

  describe "サブタスクの日時設定・変更・解除 (UC-4)" do
    let!(:parent_task) { user.tasks.create!(title: "親タスク", due_at: 3.days.from_now) }
    let!(:existing_subtask) { parent_task.children.create!(user: user, title: "期限テスト用サブタスク", due_at: nil) }

    before do
      visit task_path(parent_task)
    end

    it "AC-1, AC-2, AC-4: サブタスクの期限を設定・変更・解除でき、非同期で表示が更新されること" do
      # 初期状態では「期限なし」と表示されていることを確認
      within("#task_#{existing_subtask.id}") do
        expect(page).to have_content("期限なし")
        find("button[aria-controls='subtask-menu-#{existing_subtask.id}']").click
        click_link "編集" # または「編集」フォーム内での日時指定
      end

      # 期限を設定
      within("#task_#{existing_subtask.id}") do
        fill_in "due_at", with: 1.day.from_now.strftime("%Y-%m-%dT%H:%M")
        click_button "保存"
      end

      # リロードなしで期限の表示（フォーマット済み）に更新されること
      expect(page).not_to have_content("期限なし")
      expect(page).to have_content("明日") # またはプロジェクトの指定フォーマット
    end

    it "AC-3: 親タスクの期限を超える日時を設定するとエラーになり保存されないこと" do
      within("#task_#{existing_subtask.id}") do
        find("button[aria-controls='subtask-menu-#{existing_subtask.id}']").click
        click_link "編集"
        # 親の期限(3日後)を超える4日後を指定
        fill_in "due_at", with: 4.days.from_now.strftime("%Y-%m-%dT%H:%M")
        click_button "保存"
      end

      expect(page).to have_css(".text-red-600")
    end
  end

  describe "サブタスクの完了・未完了状態のトグル (UC-5)" do
    let!(:parent_task) { user.tasks.create!(title: "親タスク", due_at: 3.days.from_now) }
    let!(:subtask1) { parent_task.children.create!(user: user, title: "サブタスク1", status: :todo) }
    let!(:subtask2) { parent_task.children.create!(user: user, title: "サブタスク2", status: :todo) }
    let!(:subtask3) { parent_task.children.create!(user: user, title: "サブタスク3", status: :todo) }

    before do
      visit task_path(parent_task)
    end

    it "AC-1, AC-4: チェックすると非表示になり、親タスクの進捗がリアルタイムに更新されること" do
      expect(progress_text).to eq "0/3 完了"
      expect(page).to have_content("サブタスク1")

      check_of("サブタスク1").click
      # 非同期更新を待機する
      expect(page).to have_no_content("サブタスク1")
      expect(progress_text).to eq "1/3 完了"
    end

    it "AC-2, AC-3: 「完了済みを表示」で打ち消し線付きで再表示され、チェックを外すと未完了に戻ること" do
      check_of("サブタスク2").click
      expect(page).to have_no_content("サブタスク2")
      expect(progress_text).to eq "1/3 完了"

      click_on "完了済みを表示"

      # card() ヘルパーの代わりに have_css で柔軟に待機・検証
      expect(page).to have_css("li[data-done='true']", text: "サブタスク2")
      expect(line_through?("サブタスク2")).to be true
      expect(check_of("サブタスク2")["aria-label"]).to eq "「サブタスク2」を未完了に戻す"

      check_of("サブタスク2").click

      # 再度の非同期更新を待機
      expect(page).to have_css("li[data-done='false']", text: "サブタスク2")
      expect(line_through?("サブタスク2")).to be false
      expect(progress_text).to eq "0/3 完了"
    end

    it "すべてのタスクが完了した場合、全完了の空状態（Empty State）が表示されること" do
      expect(page).to have_no_text("すべての手順が完了しました")

      # Turbo Streamの通信が被らないよう、1つずつ消えるのを確認しながらクリックする
      check_of("サブタスク1").click
      expect(page).to have_no_content("サブタスク1")

      check_of("サブタスク2").click
      expect(page).to have_no_content("サブタスク2")

      check_of("サブタスク3").click
      expect(page).to have_text("すべての手順が完了しました")
      expect(progress_text).to eq "3/3 完了"
    end
  end
end
