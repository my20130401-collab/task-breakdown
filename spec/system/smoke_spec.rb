require "rails_helper"

# JavaScript（Stimulus）を動かす system spec の基盤が、ローカルと CI の両方で動くことを確かめる
RSpec.describe "JS system spec の基盤", :js do
  let(:user) { create(:user) }

  before do
    # 本実装の root_path は認証が必要なため、ログインしてから各テストを実行する
    visit new_session_path
    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: "password123"
    click_on "ログイン"
  end

  it "入力例チップを押すと入力欄に例文が入る" do
    visit root_path

    textarea = find("textarea[aria-label='取り組みたいこと']")
    expect(textarea.value).to eq ""

    click_on "資格試験の学習計画を立てる"

    expect(textarea.value).to eq "資格試験の学習計画を立てる"
    expect(page).to have_css("textarea:focus")
  end

  # 外部フォントの応答待ちで Ferrum がタイムアウトしないよう、テストでは Web フォントを読み込まない
  # （遮断したリクエストは通信履歴に残らないので、フォントの通信が 1 件も無いことで確かめる）
  it "Web フォント（fonts.googleapis.com / fonts.gstatic.com）を読み込まない" do
    visit root_path
    expect(page).to have_css("h1")

    urls = page.driver.network_traffic.map { it.url.to_s }
    expect(urls).to include(a_string_matching(%r{/assets/tailwind-}))
    expect(urls.grep(%r{\Ahttps://fonts\.(googleapis|gstatic)\.com/})).to be_empty
  end
end
