require "rails_helper"

RSpec.describe "タスク機能", :js do
  let!(:user) do
    User.create!(
      name: "タスク作成 テスター",
      email_address: "task_creator@example.com",
      password: "password123",
      terms_accepted_at: Time.current
    )
  end

  before do
    # ログインしてホーム画面（/）へ移動
    visit new_session_path
    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: "password123"
    click_on "ログイン"
  end

  # ------------------------------------------------------------
  # 1: フォーム入力とボタン送信、ショートカットキー送信
  # ------------------------------------------------------------
  describe "タスク作成フロー" do
    it "タイトルを入力してボタンをクリックするとタスクが作成され、詳細画面へ遷移する" do
      find("textarea[aria-label='取り組みたいこと']").fill_in(with: "営業用の見積もりを作成する")
      click_on "タスクを分解する"

      # 詳細モック画面へ遷移し、完了メッセージが表示されること
      expect(page).to have_current_path(task_detail_mock_path)
      expect(page).to have_content(I18n.t("tasks.create.success"))
    end

    it "タイトルを入力してショートカットキー（Ctrl/Cmd + Enter）でタスクを作成できる" do
      textarea = find("textarea[aria-label='取り組みたいこと']")
      textarea.fill_in(with: "ショートカット送信のテスト")

      # キーボードショートカットの送信
      textarea.send_keys([ :control, :enter ])

      # 詳細モック画面へ遷移し、完了メッセージが表示されること
      expect(page).to have_current_path(task_detail_mock_path)
      expect(page).to have_content(I18n.t("tasks.create.success"))
    end
  end

  # ------------------------------------------------------------
  # 2: 入力例チップによる自動入力
  # ------------------------------------------------------------
  describe "入力例チップの連動" do
    it "入力例チップを押すと、テキストエリアにその例文が挿入される" do
      # Task モデルに定義した定数の1件目をクリック
      target_example = Task::EXAMPLES.first
      click_on target_example

      # テキストエリアの値が例文で更新されていること
      expect(find("textarea[aria-label='取り組みたいこと']").value).to eq(target_example)
    end
  end

  # ------------------------------------------------------------
  # 3: 空欄などのバリデーション
  # ------------------------------------------------------------
  describe "バリデーションエラー" do
    it "空欄のまま送信しようとすると送信されない（画面遷移しない）" do
      # 空のままボタンをクリック
      click_on "タスクを分解する"

      # ホーム画面にとどまっていること
      expect(page).to have_current_path(root_path)
    end
  end

  # ------------------------------------------------------------
  # 4: マイタスク一覧画面（S-5）の表示と並び替え
  # ------------------------------------------------------------
  describe "マイタスク一覧画面（S-5）" do
    context "タスクが1件もない場合" do
      it "空状態のメッセージとタスク作成ボタンが表示される" do
        visit tasks_path

        expect(page).to have_content("まだタスクがありません")
        expect(page).to have_link("タスクを作る", href: root_path)
      end
    end

    context "複数のタスクが登録されている場合" do
      before do
        # 1. 今日のタスク
        user.tasks.create!(
          title: "今日のタスク",
          due_at: Time.current.end_of_day
        )

        # 2. 明日のタスク
        user.tasks.create!(
          title: "明日のタスク",
          due_at: 1.day.from_now.noon
        )

        # 3. 期限なしタスク
        user.tasks.create!(
          title: "期限なしタスク",
          due_at: nil
        )

        # 4. サブタスク付きタスク
        parent = user.tasks.create!(
          title: "サブタスク付きタスク",
          due_at: 2.days.from_now.noon
        )
        parent.children.create!(user: user, title: "サブタスク1", status: :done)
        parent.children.create!(user: user, title: "サブタスク2", status: :todo)
      end

      it "期限の近い順に並び、日付見出しが付き、期限なしは末尾にまとまり、進捗が表示される（AC-1, AC-2）" do
        visit tasks_path

        # 見出しが存在すること
        expect(page).to have_content("今日")
        expect(page).to have_content("明日")
        expect(page).to have_content("期限なし")

        # タスクが期限順（今日 → 明日 → 2日後 → 期限なし）に並んでいることを検証
        today_pos = page.text.index("今日のタスク")
        tomorrow_pos = page.text.index("明日のタスク")
        subtasks_pos = page.text.index("サブタスク付きタスク")
        no_due_pos = page.text.index("期限なしタスク")

        expect(today_pos).to be < tomorrow_pos
        expect(tomorrow_pos).to be < subtasks_pos
        expect(subtasks_pos).to be < no_due_pos

        # 進捗表示の検証（サブタスクあり：1/2 完了、なし：—）
        expect(page).to have_content("1/2 完了")
        expect(page).to have_content("—")
      end
    end
  end

  # ------------------------------------------------------------
  # 5: タスクの編集（AC-3）
  # ------------------------------------------------------------
  describe "タスクの編集" do
    let!(:task) { user.tasks.create!(title: "編集前のタスク", due_at: 1.day.from_now) }

    it "行メニューから編集画面を開き、タイトルを変更して保存できる" do
      visit tasks_path

      # 行メニュー「…」を開いて「編集」をクリック
      find("button[aria-label='「#{task.title}」のメニュー']").click
      click_on "編集"

      # 編集画面へ遷移したことを確認
      expect(page).to have_current_path(edit_task_path(task))
      expect(page).to have_content("タスクの編集")

      # タイトルを書き換えて保存（name 属性で直接フィールドを特定）
      find("input[name='task[title]']").fill_in(with: "編集後のタスクタイトル")
      click_on "変更を保存する"

      # 一覧画面に戻り、フラッシュメッセージと変更後タイトルが表示されること
      expect(page).to have_current_path(tasks_path)
      expect(page).to have_content(I18n.t("tasks.update.success"))
      expect(page).to have_content("編集後のタスクタイトル")
      expect(page).not_to have_content("編集前のタスク")
    end
  end

  # ------------------------------------------------------------
  # 6: タスクの削除（AC-3）
  # ------------------------------------------------------------
  describe "タスクの削除" do
    let!(:task) { user.tasks.create!(title: "削除予定のタスク", due_at: 1.day.from_now) }

    it "行メニューから削除を選び、確認ダイアログでOKを押すとタスクが削除される" do
      visit tasks_path

      expect(page).to have_content("削除予定のタスク")

      # 行メニュー「…」を開いて「削除」をクリック（確認ダイアログを自動で承認）
      find("button[aria-label='「#{task.title}」のメニュー']").click
      accept_confirm("本当に削除しますか？") do
        click_on "削除"
      end

      # 一覧画面にとどまり、フラッシュメッセージが表示されタスクが消えていること
      expect(page).to have_current_path(tasks_path)
      expect(page).to have_content(I18n.t("tasks.destroy.success"))
      expect(page).not_to have_content("削除予定のタスク")
    end
  end
end
