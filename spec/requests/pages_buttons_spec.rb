require "rails_helper"

# 横断検査: Pages::ALL の全画面（ログイン前・ログイン後）のボタンは「フォームの送信」か「Stimulus の操作」のどちらかで、
# 押しても何も起きない無規約のボタンや、見た目だけのボタン（data-mock="noop"）が無い
RSpec.describe "画面のボタン（横断検査）" do
  before { travel_to(Time.zone.local(2026, 6, 20, 10, 0)) }

  def rule_of(button)
    if button["type"] == "submit" && button.ancestors("form").any? then :submit
    elsif button["data-action"].present? then :action
    end
  end

  Pages::ALL.each do |page_name|
    describe page_name do
      before { get_page(page_name) }

      it "すべての <button> が送信・操作のいずれかに当たる" do
        violations = pages_document.css("button").reject { rule_of(it) }.map { "「#{element_name(it)}」" }

        expect(violations).to be_empty, "規約に当たらないボタン: #{violations.join('、')}"
      end

      it "すべての <button> が type を明示している（フォーム内で意図せず送信しない）" do
        violations = pages_document.css("button:not([type])").map { "「#{element_name(it)}」" }

        expect(violations).to be_empty, "type の無いボタン: #{violations.join('、')}"
      end

      it "見た目だけのボタン（data-mock=\"noop\"）が 0 件" do
        noops = pages_document.css("[data-mock='noop']").map { "「#{element_name(it)}」" }

        expect(noops).to be_empty, "見た目だけのボタン: #{noops.join('、')}"
      end
    end
  end

  # 規約・ポリシーの画面にはボタンが無いため、画面単位ではなく巡回全体で空集合を弾く。
  # 見た目だけのボタンが出やすいログイン後の画面（メニュー・完了チェック・再分解）は、それだけでも 1 件以上あることを確かめる
  it "巡回した画面の <button> が 1 件以上ある（検査が空集合で素通りしない）" do
    counts = Pages::ALL.index_with do |page_name|
      get_page(page_name)
      pages_document.css("button").size
    end

    expect(counts.values.sum).to be_positive
    expect(counts.values_at(*Pages::AUTHENTICATED_PAGES.keys)).to all(be_positive)
  end
end
