require "rails_helper"

RSpec.describe Evals::EvalCase do
  it "評価事例はペルソナの 3 事例で、期限は相対指定・件数は 3〜8 件・参照する観点はすべて定義済み" do
    expect(described_class.names).to eq %w[estimate expense proposal]

    described_class.all.each do |eval_case|
      expect(eval_case.title).to be_present
      expect(eval_case.due_in).to match(described_class::DURATION_FORMAT)
      expect(eval_case.count_range).to eq 3..8
      expect(eval_case.aspects).to all(include("name", "keywords"))

      aspect_names = eval_case.aspects.map { |aspect| aspect["name"] }
      expect(eval_case.order_chains.flatten + eval_case.special_aspects).to all(be_in(aspect_names))
    end
  end

  it "起案書は「決裁基準」→「承認」→「申請」の順序制約を持つ" do
    expect(described_class.load("proposal").order_chains).to include(%w[決裁基準の確認 上司の承認 起案書の申請])
  end

  it "親の期限は評価時刻 + due_in" do
    now = Time.zone.parse("2026-10-26 09:00")

    expect(described_class.load("estimate").due_at(now)).to eq Time.zone.parse("2026-10-26 17:00")
    expect(described_class.load("expense").due_at(now)).to eq Time.zone.parse("2026-10-29 09:00")
  end

  it "due_in は m / h / d の相対指定だけを受け付ける" do
    expect(described_class.parse_duration("30m")).to eq 30.minutes
    expect(described_class.parse_duration("8h")).to eq 8.hours
    expect { described_class.parse_duration("2026-10-26") }.to raise_error(ArgumentError, /due_in の形式/)
  end

  it "存在しない事例名やパスを含む名前はエラーにする" do
    expect { described_class.load("unknown") }
      .to raise_error(ArgumentError, /評価事例が見つかりません: unknown（estimate/)
    expect { described_class.load("../cases/estimate") }.to raise_error(ArgumentError)
  end
end
