require "rails_helper"

# 横断検査: Pages::PATHS の全画面のボタンは「フォームの送信」か「Stimulus の操作」のどちらかで、
# 押しても何も起きない無規約のボタンや、見た目だけのボタン（data-mock="noop"）が無い
RSpec.describe "画面のボタン（横断検査）" do
  before { travel_to(Time.zone.local(2026, 6, 20, 10, 0)) }

  def rule_of(button)
    if button["type"] == "submit" && button.ancestors("form").any? then :submit
    elsif button["data-action"].present? then :action
    end
  end

  Pages::PATHS.each do |page_path|
    describe page_path do
      before { get page_path }

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

  # 規約・ポリシーの画面にはボタンが無いため、画面単位ではなく巡回全体で空集合を弾く
  it "巡回した画面の <button> が 1 件以上ある（検査が空集合で素通りしない）" do
    count = Pages::PATHS.sum do |page_path|
      get page_path
      pages_document.css("button").size
    end

    expect(count).to be_positive
  end
end
