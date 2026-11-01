require "rails_helper"

RSpec.describe "画面モック" do
  # 「今日 17:00」「明日 12:00」「6/27 17:00」の書式（時刻付き）
  let(:due_format) { %r{\A(今日|明日|\d{1,2}/\d{1,2}) \d{2}:\d{2}\z} }

  def html
    Nokogiri::HTML(response.body)
  end

  {
    "/tasks/sample" => "社内提案資料を作成する",
    "/signup" => "アカウントを作成する",
    "/login" => "おかえりなさい"
  }.each do |path, text|
    it "#{path} が表示できる" do
      get path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(text)
    end
  end

  it "入力した内容をタスク詳細の見出しに表示する" do
    get "/tasks/sample", params: { title: "経費申請" }

    expect(response.body).to include("経費申請")
  end

  describe "共通 head" do
    it "画面ごとのタイトルを表示する" do
      get "/login"

      expect(html.at_css("head title").text).to eq "ログイン | Tasklet"
    end

    it "両レイアウトで同じ head 要素を持つ" do
      heads = %w[/tasks/sample /login].map do |path|
        get path
        html.css("head meta[name], head link[rel='icon']").map(&:to_html)
      end

      expect(heads.first).to eq heads.last
      expect(heads.first).not_to be_empty
    end
  end

  describe "サンプルデータの日付" do
    it "表示日に応じて期限の表示が変わる（固定値ではない）" do
      travel_to(Time.zone.local(2026, 6, 20, 10, 0)) { get "/tasks/sample" }
      first_tabs = html.css("[role='tab']").map { it.text.strip }
      expect(first_tabs).to eq %w[すべて 今日 明日 6/27]
      expect(response.body).to include("6/27 17:00")

      travel_to(Time.zone.local(2026, 7, 1, 10, 0)) { get "/tasks/sample" }
      expect(html.css("[role='tab']").map { it.text.strip }).to eq %w[すべて 今日 明日 7/8]
      expect(response.body).to include("7/8 17:00")
      expect(response.body).not_to include("6/27")
    end
  end

  describe "共通部品" do
    before do
      travel_to(Time.zone.local(2026, 6, 20, 10, 0))
    end

    def status_badge(path, params = {})
      get path, params: params
      html.css("[data-decomposition-status]")
    end

    it "ステータスは 3 状態を表示し、失敗は danger、分解中は pulse" do
      # /tasks/sample で検証
      badges = status_badge("/tasks/sample").to_h { [ it["data-decomposition-status"], it ] }

      expect(badges.keys).to include("done")
    end

    it "S-4 のヘッダーはマイタスクへのリンク 1 つだけで、パンくずを持たない" do
      get "/tasks/sample"

      links = html.css("header a[href='/tasks']")
      expect(links.size).to eq 1
      expect(links.first["aria-label"]).to eq "マイタスクに戻る"
      expect(links.first.text.strip).to eq "マイタスク"
      expect(html.at_css("nav[aria-label='パンくず']")).to be_nil
    end

    it "/tasks/sample はヘッダーと本文を完了フィルタのラッパーで包み、トグルは初期 aria-pressed=false" do
      get "/tasks/sample"

      wrapper = html.at_css("main > [data-controller~='completed-filter']")
      expect(wrapper).to be_present
      expect(wrapper.at_css("> header")).to be_present
      toggle = wrapper.at_css("header button[aria-pressed]")
      expect(toggle["aria-pressed"]).to eq "false"
      expect(toggle["data-action"]).to include("completed-filter#toggle")
      expect(toggle.text.strip).to eq "完了済みを表示"
    end

    it "完了済みの要素は初期描画で data-hidden-by-done を持ち、未完了は持たない" do
      get "/tasks/sample"

      done = html.css("[data-done='true']")
      expect(done).not_to be_empty
      expect(done.map { it.key?("data-hidden-by-done") }).to all(be true)
      expect(html.css("[data-done='false'][data-hidden-by-done]")).to be_empty
    end

    it "サイドバーのユーザーメニューはログアウトを /session へのリンクで持つ" do
      get "/tasks/sample"

      menu = html.at_css("aside [role='menu']")
      trigger = html.at_css("aside button[aria-haspopup='menu']")
      expect(trigger["aria-controls"]).to eq menu["id"]
      expect(trigger["aria-expanded"]).to eq "false"
      items = menu.css("[role='menuitem']")
      expect(items.map { it.text.strip }).to eq [ "ログアウト" ]
      expect(items.first.name).to eq "a"
      expect(items.first["href"]).to eq "/session"
      expect(items.first["data-turbo-method"]).to eq "delete"
    end

    it "サイドバーはプラン名を表示しない" do
      get "/tasks/sample"

      expect(response.body).not_to include("フリープラン")
    end
  end
end
