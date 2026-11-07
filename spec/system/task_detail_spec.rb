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
    expect(page).to have_css("ol [data-subtask-card-target='title']", text: title)
    # 完了済みリスト(ol)に限らず、ページ全体から該当するサブタスクタイトル要素の出現を待つ
    expect(page).to have_css("[data-subtask-card-target='title']", text: title)
    page.evaluate_script(<<~JS)
      getComputedStyle(Array.from(document.querySelectorAll("[data-subtask-card-target='title']"))
        .find((el) => el.textContent.trim() === #{title.to_json})).textDecorationLine.includes("line-through")
    JS
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

      before do
        parent_task.children.create!(user: user, title: "サブタスク1", status: :todo)
        parent_task.children.create!(user: user, title: "サブタスク2", status: :todo)
        parent_task.children.create!(user: user, title: "サブタスク3", status: :todo)
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

      # 完了済みのサブタスクが表示される（DOMが更新される）のを待機
      expect(page).to have_css("li[data-done='true']", text: "サブタスク2")
      expect(line_through?("サブタスク2")).to be true
      expect(check_of("サブタスク2")["aria-label"]).to eq "「サブタスク2」を未完了に戻す"

      check_of("サブタスク2").click

      # 未完了に戻ったこと（DOMが更新される）のを待機
      expect(page).to have_css("li[data-done='false']", text: "サブタスク2")
      # 打ち消し線が消えるのを待機 (evaluate_scriptの前に確実に状態が変わるのを待つ)
      expect(page).not_to have_css("li[data-done='true']", text: "サブタスク2")
      expect(line_through?("サブタスク2")).to be false
      expect(progress_text).to eq "0/3 完了"
    end

    it "すべてのタスクが完了した場合、全完了の空状態（Empty State）が表示されること" do
      expect(page).to have_no_text("すべての手順が完了しました")

      # Turbo Streamの通信が被らないよう、1つずつ消えるのを確認しながらクリックする
      check_of("サブタスク1").click
      expect(page).to have_no_content("サブタスク1")
      # 【追加】進捗が更新され、DOMの再構築が落ち着くのを待つ
      expect(page).to have_css("[data-task-progress]", text: "1/3 完了")

      check_of("サブタスク2").click
      expect(page).to have_no_content("サブタスク2")
      expect(page).to have_css("[data-task-progress]", text: "2/3 完了")

      check_of("サブタスク3").click
      expect(page).to have_no_content("サブタスク3")
      # 最後の進捗更新を確実に待つことで、Stimulus側のEmpty State表示処理完了を保証する
      expect(page).to have_css("[data-task-progress]", text: "3/3 完了")

      # UIの最終描画（フェードイン等のアニメーションやDOMの確定）を確実に待つためのウェイト

      # 確実に描画が完了してテキストが表示されるのを待機して検証する
      expect(page).to have_link("マイタスクへ", href: "/tasks")
    end
  end
end
