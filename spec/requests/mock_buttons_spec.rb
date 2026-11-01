require "rails_helper"

# 横断検査: 全モック画面のボタンは「フォームの送信」「Stimulus の操作」「見た目だけ（data-mock="noop"）」のどれかで、
# 押しても何も起きない無規約のボタンが無い
RSpec.describe "画面モックのボタン（横断検査）" do
  before { travel_to(Time.zone.local(2026, 6, 20, 10, 0)) }

  def rule_of(button)
    if button["type"] == "submit" && button.ancestors("form").any? then :submit
    elsif button["data-mock"] == "noop" then :noop
    elsif button["data-action"].present? then :action
    end
  end

  MockPages::PATHS.each do |page_path|
    describe page_path do
      before { get page_path }

      it "すべての <button> が送信・操作・見た目のみのいずれかに当たる" do
        violations = mock_document.css("button").reject { rule_of(it) }.map { "「#{element_name(it)}」" }

        expect(violations).to be_empty, "規約に当たらないボタン: #{violations.join('、')}"
      end

      it "すべての <button> が type を明示している（フォーム内で意図せず送信しない）" do
        violations = mock_document.css("button:not([type])").map { "「#{element_name(it)}」" }

        expect(violations).to be_empty, "type の無いボタン: #{violations.join('、')}"
      end

      it "見た目のみのボタンは type=button で、送信ボタンにしない" do
        noops = mock_document.css("button[data-mock='noop']")

        expect(noops.map { it["type"] }).to all(eq "button")
      end
    end
  end

  # docs/screens.md の「（見た目のみ）」と一致する
  describe "見た目のみの操作" do
    def noop_labels(path)
      get path
      mock_document.css("button[data-mock='noop']").map { it.text.squish }
    end

    it "S-4 は親タスクのメニュー（編集・再分解・削除）とサブタスクのメニュー（編集・期限設定・削除）" do
      labels = noop_labels("/tasks/sample")

      expect(labels.first(3)).to eq %w[編集 再分解 削除]
      expect(labels.drop(3).each_slice(3).to_a.uniq).to eq [ %w[編集 期限設定 削除] ]
    end

    it "S-4 の分解失敗では「再分解する」も見た目のみ" do
      expect(noop_labels("/tasks/sample?status=failed")).to eq %w[編集 再分解 削除 再分解する]
    end

    %w[/login /signup /terms /privacy].each do |path|
      it "#{path} には見た目のみのボタンが無い" do
        expect(noop_labels(path)).to be_empty
      end
    end
  end
end
