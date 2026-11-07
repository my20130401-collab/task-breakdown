require "rails_helper"

RSpec.describe "認証機能（本番フロー）", :js do
  # ------------------------------------------------------------
  # 1. 会員登録からホーム画面遷移、サイドバー表示までのフロー
  # ------------------------------------------------------------
  describe "会員登録フロー" do
    it "ユーザーが新規登録を行い、自動ログインしてサイドバーに自身の情報が表示される" do
      # 会員登録画面を開く
      visit new_registration_path

      # フォームへの入力
      fill_in "お名前", with: "新規 太郎"
      fill_in "メールアドレス", with: "new_user@example.com"
      fill_in "パスワード", with: "password123"
      fill_in "パスワード（確認）", with: "password123"
      check "利用規約とプライバシーポリシーに同意する"

      # 登録ボタンをクリック
      click_on "アカウントを作成する"

      # ホーム画面（/）へ遷移すること
      expect(page).to have_current_path(root_path)

      # サイドバー下部に、登録したユーザー名とメールアドレスが表示されていること
      within("aside") do
        expect(page).to have_content("新規 太郎")
        expect(page).to have_content("new_user@example.com")
        # 名前の頭文字アイコンが表示されていること
        expect(page).to have_content("新")
      end
    end

    it "パスワードが 8 文字未満だと送信されない" do
      visit new_registration_path
      fill_in "お名前", with: "山田 優"
      fill_in "メールアドレス", with: "yu.yamada@example.com"
      # minlength はユーザーが入力した値にだけ効くので、キー入力で打ち込む（fill_in の値設定では tooShort が立たない）
      find_field("パスワード").send_keys("pass123")
      find_field("パスワード（確認）").send_keys("pass123")
      check "利用規約とプライバシーポリシーに同意する"

      expect(page.evaluate_script("document.querySelector('input[name=\"user[password]\"]').validity.tooShort")).to be true

      click_on "アカウントを作成する"

      sleep 0.3
      expect(page).to have_current_path(new_registration_path)
      expect(page).to have_no_css("aside")
      expect(User.exists?(email_address: "yu.yamada@example.com")).to be false
    end

    it "利用規約を新しいタブで開いても、入力途中のフォームはそのまま残る" do
      visit new_registration_path
      fill_in "お名前", with: "山田 優"
      fill_in "メールアドレス", with: "yu.yamada@example.com"

      terms = window_opened_by { click_on "利用規約" }

      within_window(terms) do
        expect(page).to have_css("h1", text: "利用規約")
        expect(page).to have_link("会員登録に戻る", href: new_registration_path)
      end
      expect(page).to have_current_path(new_registration_path)
      expect(find_field("お名前").value).to eq "山田 優"
      expect(find_field("メールアドレス").value).to eq "yu.yamada@example.com"
    end
  end

  # ------------------------------------------------------------
  # 2. ログイン、サイドバー確認、ログアウトまでのフロー
  # ------------------------------------------------------------
  describe "ログイン・ログアウトフロー" do
    let!(:user) do
      User.create!(
        name: "ログイン 花子",
        email_address: "hanako@example.com",
        password: "password123",
        terms_accepted_at: Time.current
      )
    end

    it "ログイン後にサイドバー情報が表示され、メニューからログアウトできる" do
      # ログイン画面を開く
      visit new_session_path

      # フォーム入力とログイン実行
      fill_in "メールアドレス", with: user.email_address
      fill_in "パスワード", with: "password123"
      click_on "ログイン"

      # ホーム画面へ遷移すること
      expect(page).to have_current_path(root_path)

      # サイドバー下部にユーザー情報が表示されていること
      within("aside") do
        expect(page).to have_content("ログイン 花子")
        expect(page).to have_content("hanako@example.com")
        expect(page).to have_content("ロ")

        # ユーザーメニュー（…）を開く
        find("button[aria-controls='user-menu']").click
        # メニュー内の「ログアウト」をクリック
        click_on "ログアウト"
      end

      # ログアウト後、ログイン画面へ戻ること
      expect(page).to have_current_path(new_session_path)
    end
  end
end
