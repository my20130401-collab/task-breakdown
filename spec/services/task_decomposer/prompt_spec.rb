require "rails_helper"

RSpec.describe TaskDecomposer::Prompt do
  describe ".system_prompt" do
    subject(:prompt) { described_class.system_prompt }

    it "社内手続きでは最初に社内規程・基準を確認する手順を入れるよう指示する" do
      expect(prompt).to include("社内手続き", "最初のサブタスクで、その手続きの社内規程・基準を確認する")
      expect(prompt).to include("決裁基準", "勘定科目", "経費規程")
    end

    it "決裁が必要な手続きでは本申請の前に上司の事前相談・承認を special で置くよう指示する" do
      expect(prompt).to include("本申請・提出の前に上司へ事前相談して承認をもらうサブタスクを置き、kind を \"special\" にする")
    end

    it "サブタスク名に業務で使う言葉をそのまま使うよう指示する" do
      expect(prompt).to include("業務で使う言葉をそのまま使う")
    end

    it "特定の評価事例名を含まない汎用ルールである" do
      expect(prompt).not_to include("estimate", "proposal", "expense")
    end
  end
end
