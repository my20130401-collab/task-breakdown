require "rails_helper"

# 横断検査: Pages::ALL の全画面（ログイン前・ログイン後）の <title>・デザイントークン外の値・id の一意性・繰り返し部品の読み上げ名
RSpec.describe "画面の表示（横断検査）" do
  before { travel_to(Time.zone.local(2026, 6, 20, 10, 0)) }

  Pages::ALL.each do |page_name|
    describe page_name do
      before { get_page(page_name) }

      it "画面ごとの <title>（「〜 | Tasklet」）を設定している" do
        title = pages_document.at_css("head title").text

        expect(title).to match(/\A.+ \| Tasklet\z/)
      end

      it "本文にトークン外の色・文字サイズ（#xxxxxx・rgba(・text-[9px]）を書いていない" do
        expect(pages_document.at_css("body").to_html.scan(Pages::BANNED_VALUES)).to be_empty
      end

      it "id が画面内で重複しない（メニュー role=menu を含む）" do
        ids = pages_document.css("[id]").map { it["id"] }
        menu_ids = pages_document.css("[role='menu']").map { it["id"] }

        expect(menu_ids).to all(be_present)
        expect(ids.tally.select { |_, count| count > 1 }.keys).to be_empty
      end

      it "メニューのトリガーと完了チェックの読み上げ名が画面内で重複しない" do
        names = pages_document.css("[aria-haspopup='menu'], [data-subtask-card-target='check']").map { it["aria-label"] }

        expect(names).to all(be_present)
        expect(names.tally.select { |_, count| count > 1 }.keys).to be_empty
      end

      # 入力はフォームの input / textarea で受け、contenteditable は使わない
      it "最初の表示に編集可能な要素（contenteditable）が無い" do
        expect(pages_document.css("[contenteditable]")).to be_empty
      end
    end
  end

  # 巡回の準備（Pages::AUTHENTICATED_PAGES）が狙った状態の画面を開いているか。ずれると検査が別の画面に当たる
  describe "ログイン後の巡回データ" do
    def open(page_name)
      get_page(page_name)
      pages_document
    end

    it "S-4 は分解中・分解完了・分解失敗・全完了の 4 状態を開く" do
      docs = Pages::AUTHENTICATED_PAGES.keys.grep(/S-4/).map { open(it) }

      expect(docs.map { it.at_css("[data-decomposition-status]")["data-decomposition-status"] }).to eq %w[decomposing done failed done]
      expect(docs.map { it.css("[data-subtask-card-target='check']").size }).to eq [ 0, 3, 0, 2 ]
      expect(docs.last.at_css("[data-completed-filter-target='empty']")["hidden"]).to be_nil
    end

    it "S-5 はデータありと 0 件の両方を開く" do
      expect(open("/tasks（S-5 マイタスク。データあり）").css("li[data-done]").size).to eq 4
      expect(open("/tasks（S-5 マイタスク。0 件）").at_css("[data-my-tasks-empty]")).to be_present
    end
  end

  it "app/views にトークン外の色・文字サイズを書いていない" do
    offenders = Rails.root.glob("app/views/**/*.erb").filter_map do |file|
      file.relative_path_from(Rails.root).to_s if file.read.match?(Pages::BANNED_VALUES)
    end

    expect(offenders).to be_empty
  end
end
