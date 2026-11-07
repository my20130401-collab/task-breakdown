require "rails_helper"

# S-6 利用規約・S-7 プライバシーポリシー
RSpec.describe "利用規約・プライバシーポリシー" do
  let!(:user) do
    User.create!(
      name: "規約確認ユーザー",
      email_address: "legal@example.com",
      password: "password123",
      terms_accepted_at: Time.current
    )
  end

  def document
    Nokogiri::HTML(response.body)
  end

  def body_text
    document.at_css("article").text.squish
  end

  shared_examples "法的ページ" do |path:, title:, eyebrow:|
    it "未ログインで表示できる" do
      get path

      expect(response).to have_http_status(:ok)
    end

    it "ログイン済みでも表示できる" do
      post session_path, params: { email_address: user.email_address, password: "password123" }
      get path

      expect(response).to have_http_status(:ok)
    end

    it "見出し・<title>・会員登録へ戻るリンクがあり、サイドバーの無いレイアウトで開く" do
      get path

      expect(document.at_css("head title").text).to eq "#{title} | Tasklet"
      expect(document.at_css("h1").text.squish).to eq title
      expect(document.text).to include(eyebrow)
      back = document.css("a").find { it.text.squish == "会員登録に戻る" }
      expect(back&.[]("href")).to eq new_registration_path
      expect(document.at_css("aside")).to be_nil
    end

    it "ハッカソンのデモ用である旨を明記し、サンプルの文面ではない" do
      get path

      expect(document.text).to include("ハッカソン")
      expect(document.text).to include("デモ")
      expect(document.text).not_to include("サンプル")
      expect(document.text).not_to include("差し替え")
    end

    it "メールアドレス等の個人の連絡先を書かない" do
      get path

      expect(body_text).not_to match(/[\w.+-]+@[\w-]+\.[\w.]+/)
      expect(document.css("a[href^='mailto:']")).to be_empty
    end
  end

  describe "GET /terms" do
    it_behaves_like "法的ページ", path: "/terms", title: "利用規約", eyebrow: "TERMS OF SERVICE"

    it "サービス内容・デモの保証範囲・禁止事項・データ削除・規約の変更・問い合わせ先を含む" do
      get terms_path

      expect(body_text).to include("AI", "分解")
      expect(body_text).to include("継続", "可用性", "保全")
      expect(body_text).to include("個人情報", "機密情報")
      expect(body_text).to include("アカウント", "サービス終了", "削除")
      expect(body_text).to include("変更")
      expect(body_text).to include("運営チャンネル")
    end
  end

  describe "GET /privacy" do
    it_behaves_like "法的ページ", path: "/privacy", title: "プライバシーポリシー", eyebrow: "PRIVACY POLICY"

    it "取得する情報・利用目的・OpenAI への送信・第三者提供・保存期間・削除依頼・Cookie を含む" do
      get privacy_path

      expect(body_text).to include("氏名", "メールアドレス", "パスワード", "ハッシュ化")
      expect(body_text).to include("タスク", "サブタスク", "期限", "User-Agent", "IP アドレス")
      expect(body_text).to include("利用目的")
      expect(body_text).to include("OpenAI")
      expect(body_text).to include("氏名・メールアドレスは送信しません")
      expect(body_text).to include("第三者")
      expect(body_text).to include("Google Fonts", "Google のサーバーへ、IP アドレス")
      expect(body_text).to include("保存期間", "デモ期間")
      expect(body_text).to include("削除", "運営チャンネル")
      expect(body_text).to include("Cookie", "セッション ID")
    end
  end

  describe "会員登録画面の規約リンク" do
    it "利用規約・プライバシーポリシーを新しいタブで開き、opener を渡さず、注記に結ぶ" do
      get new_registration_path
      links = document.css("form label a")

      expect(links.map { it["href"] }).to eq [ terms_path, privacy_path ]
      expect(links.map { it["target"] }).to all(eq "_blank")
      expect(links.map { it["rel"].to_s.split }).to all(include("noopener"))
      expect(links.map { it["aria-describedby"] }).to all(eq "terms-new-tab")
      expect(document.at_css("#terms-new-tab")).to be_present
    end
  end
end
