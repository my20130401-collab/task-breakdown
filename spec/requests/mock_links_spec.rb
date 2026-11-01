require "rails_helper"

# 横断検査: 全モック画面のリンクと送信先が、アプリのルーティングで解決できる（死にリンクが無い）
RSpec.describe "画面モックのリンクと送信先（横断検査）" do
  before { travel_to(Time.zone.local(2026, 6, 20, 10, 0)) }

  # 要素の遷移先を [パス, HTTP メソッド] にする。外部 URL・# だけのリンクは nil（違反）
  def destination(node)
    if node.name == "form"
      url = node["action"]
      method = node.at_css("input[name='_method']")&.[]("value") || node["method"].presence || "get"
    else
      url = node["href"]
      method = node["data-turbo-method"].presence || "get"  # data-turbo-method を拾うように修正
    end
    return nil if url.blank? || url.start_with?("#", "javascript:")

    uri = URI.parse(url)
    return nil if uri.host.present? || uri.path.blank?

    [ uri.path, method.downcase.to_sym ]
  end

  def routable?(path, method)
    Rails.application.routes.recognize_path(path, method:)
    true
  rescue ActionController::RoutingError
    false
  end

  MockPages::PATHS.each do |page_path|
    describe page_path do
      before { get page_path }

      it "表示できる" do
        expect(response).to have_http_status(:ok)
      end

      it "すべての <a href> と <form action> がルーティングで解決できる（# や外部 URL を含まない）" do
        nodes = mock_document.css("a, form")
        violations = nodes.filter_map do |node|
          dest = destination(node)
          next if dest && routable?(*dest)

          "#{node.name}「#{element_name(node)}」→ #{node.name == 'form' ? node['action'] : node['href'].inspect}"
        end

        expect(nodes).not_to be_empty
        expect(violations).to be_empty, "解決できない遷移先:\n#{violations.join("\n")}"
      end

      it "外部への参照は Web フォントだけ" do
        urls = mock_document.css("[href], [src], [action]").filter_map { it["href"] || it["src"] || it["action"] }
        external = urls.filter_map { URI.parse(it).host }.uniq

        expect(external - MockPages::ALLOWED_EXTERNAL_HOSTS).to be_empty
      end
    end
  end

  describe "画面ごとの遷移先" do
    def recognized(url, method: :get)
      Rails.application.routes.recognize_path(URI.parse(url).path, method:).values_at(:controller, :action).join("#")
    end

    # S-5関連の2つの it ブロックは削除し、ログアウト確認のみ /tasks/sample で検証する
    it "サイドバーのユーザーメニュー「ログアウト」は S-1 へ移る" do
      get "/tasks/sample"

      expect(mock_document.at_css("#user-menu a[role='menuitem']")).to have_attributes(text: "ログアウト")
      expect(mock_document.at_css("#user-menu a[role='menuitem']")["href"]).to eq "/session"
    end

    { "/login" => "mocks#login_submit", "/signup" => "mocks#signup_submit" }.each do |path, action|
      it "#{path} のフォームは POST で送信し、#{action} が受ける" do
        get path
        form = mock_document.at_css("form")

        expect(form["method"]).to eq "post"
        expect(recognized(form["action"], method: :post)).to eq action
      end
    end

    it "S-2 の同意文の規約リンクは新しいタブで開き、opener を渡さない" do
      get "/signup"
      links = mock_document.css("form label a")

      expect(links.map { it["href"] }).to eq %w[/terms /privacy]
      expect(links.map { it["target"] }).to all(eq "_blank")
      expect(links.map { it["rel"].to_s.split }).to all(include("noopener"))
    end

    %w[/login /signup /terms /privacy].each do |path|
      it "#{path} はサイドバーの無いログイン前のレイアウトで、ロゴは S-3 へ移る" do
        get path

        expect(mock_document.at_css("aside")).to be_nil
        expect(mock_document.at_css("main > a")["href"]).to eq "/"
        expect(mock_document.at_css("main > a").text).to include("Tasklet")
      end
    end
  end
end
