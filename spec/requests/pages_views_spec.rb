require "rails_helper"

# 横断検査: 全モック画面の <title>・デザイントークン外の値・id の一意性・繰り返し部品の読み上げ名
RSpec.describe "画面モックの表示（横断検査）" do
  before { travel_to(Time.zone.local(2026, 6, 20, 10, 0)) }

  MockPages::PATHS.each do |page_path|
    describe page_path do
      before { get page_path }

      it "画面ごとの <title>（「〜 | Tasklet」）を設定している" do
        title = mock_document.at_css("head title").text

        expect(title).to match(/\A.+ \| Tasklet\z/)
      end

      it "本文にトークン外の色・文字サイズ（#xxxxxx・rgba(・text-[9px]）を書いていない" do
        expect(mock_document.at_css("body").to_html.scan(MockPages::BANNED_VALUES)).to be_empty
      end

      it "id が画面内で重複しない（メニュー role=menu を含む）" do
        ids = mock_document.css("[id]").map { it["id"] }
        menu_ids = mock_document.css("[role='menu']").map { it["id"] }

        expect(menu_ids).to all(be_present)
        expect(ids.tally.select { |_, count| count > 1 }.keys).to be_empty
      end

      it "メニューのトリガーと完了チェックの読み上げ名が画面内で重複しない" do
        names = mock_document.css("[aria-haspopup='menu'], [data-subtask-card-target='check']").map { it["aria-label"] }

        expect(names).to all(be_present)
        expect(names.tally.select { |_, count| count > 1 }.keys).to be_empty
      end

      # その場で入力できるのは「タスクを追加」で足したカードだけ（ひな形の <template> は検査対象外）
      it "最初の表示に編集可能な要素（contenteditable）が無い" do
        expect(mock_document.css("[contenteditable]")).to be_empty
      end
    end
  end

  it "app/views にトークン外の色・文字サイズを書いていない" do
    offenders = Rails.root.glob("app/views/**/*.erb").filter_map do |file|
      file.relative_path_from(Rails.root).to_s if file.read.match?(MockPages::BANNED_VALUES)
    end

    expect(offenders).to be_empty
  end
end
