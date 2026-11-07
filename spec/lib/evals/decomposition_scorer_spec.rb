require "rails_helper"

RSpec.describe Evals::DecompositionScorer do
  # Llm::FakeClient::DEFAULT_RESPONSE の期限（2026-10-26 15:00〜17:00）が「現在〜親の期限」に収まる時刻
  let(:now) { Time.zone.parse("2026-10-26 09:00") }
  let(:estimate) { Evals::EvalCase.load("estimate") }
  let(:proposal) { Evals::EvalCase.load("proposal") }

  def score(eval_case, response)
    described_class.new(eval_case: eval_case, response: response, now: now).call
  end

  def check_named(result, name, category: nil)
    result.checks.find { |check| check.name == name && (category.nil? || check.category == category) } ||
      raise("採点項目がありません: #{name}")
  end

  def subtask(title, kind: "basic", due_at: "2026-10-26T12:00:00+09:00")
    { title: title, description: nil, kind: kind, estimated_minutes: 10, due_at: due_at }
  end

  describe "合格例" do
    it "Llm::FakeClient::DEFAULT_RESPONSE は見積もり作成の全項目が OK になる" do
      result = score(estimate, Llm::FakeClient::DEFAULT_RESPONSE)

      expect(result).to be_passed
      expect(result.checks.map(&:category).uniq).to eq %i[count aspect order special due]
      expect(result.checks.map(&:name)).to include(
        "件数", "仕入れ先への依頼", "見積書の作成", "見積書の提出",
        "仕入れ先への依頼 → 見積書の作成 → 見積書の提出", "期限の範囲", "期限の順序"
      )
      expect(check_named(result, "仕入れ先への依頼", category: :aspect).reason).to eq "1 件目「仕入れ先に見積もりを依頼する」"
      expect(check_named(result, "仕入れ先への依頼", category: :special).reason).to eq "1 件目が special"
    end

    it "起案書の分解例（few-shot）と同じ分解は合格になる（キーが文字列でもよい）" do
      response = {
        "subtasks" => [
          subtask("決裁基準を確認する", due_at: "2026-10-27T10:00:00+09:00"),
          subtask("必要書類を準備する", due_at: "2026-10-27T15:00:00+09:00"),
          subtask("起案書を作成する", due_at: "2026-10-28T12:00:00+09:00"),
          subtask("管理部へ事前確認する", kind: "special", due_at: "2026-10-29T12:00:00+09:00"),
          subtask("上司へ事前相談し承認をもらう", kind: "special", due_at: "2026-10-30T12:00:00+09:00"),
          subtask("起案書を本申請する", due_at: "2026-10-31T09:00:00+09:00")
        ].map(&:deep_stringify_keys)
      }

      expect(score(proposal, response)).to be_passed
    end

    it "観点の順序は、前の観点の手順が後の観点の最後の手順より前にあれば OK（途中で同じ語が出てもよい）" do
      response = { subtasks: [
        subtask("決裁基準と申請の流れを確認する"),
        subtask("必要書類を準備する"),
        subtask("上司の承認をもらう", kind: "special"),
        subtask("起案書を申請する")
      ] }

      expect(check_named(score(proposal, response), "決裁基準の確認 → 上司の承認 → 起案書の申請")).to be_ok
    end
  end

  describe "不合格例" do
    it "見積もりの分解で起案書を採点すると、観点・順序・special が NG で理由が付く" do
      result = score(proposal, Llm::FakeClient::DEFAULT_RESPONSE)

      expect(result).not_to be_passed
      expect(check_named(result, "決裁基準の確認"))
        .to have_attributes(ok: false, reason: include("該当する手順がない", "決裁基準"))
      expect(check_named(result, "上司の承認", category: :special))
        .to have_attributes(ok: false, reason: "該当する手順がない")
      expect(check_named(result, "決裁基準の確認 → 上司の承認 → 起案書の申請").reason)
        .to eq "「決裁基準の確認」の手順がない"
      expect(check_named(result, "件数")).to be_ok
      expect(result.failures).to all(have_attributes(ok: false))
    end

    it "件数が範囲外なら NG" do
      result = score(estimate, { subtasks: Llm::FakeClient::DEFAULT_RESPONSE[:subtasks].first(2) })

      expect(check_named(result, "件数")).to have_attributes(ok: false, reason: "2 件（期待: 3〜8 件）")
    end

    it "応答にサブタスクが無ければ件数・期限とも NG" do
      result = score(estimate, { subtasks: [] })

      expect(result).not_to be_passed
      expect(check_named(result, "件数")).not_to be_ok
      expect(check_named(result, "期限の範囲").reason).to eq "サブタスクがない"
    end

    it "観点の順序が逆なら NG" do
      response = { subtasks: [
        subtask("見積書を提出する", due_at: "2026-10-26T15:00:00+09:00"),
        subtask("見積書を作成する", due_at: "2026-10-26T16:00:00+09:00"),
        subtask("仕入れ先に見積もりを依頼する", kind: "special", due_at: "2026-10-26T17:00:00+09:00")
      ] }

      expect(check_named(score(estimate, response), "仕入れ先への依頼 → 見積書の作成 → 見積書の提出"))
        .to have_attributes(ok: false, reason: "「仕入れ先への依頼」が「見積書の作成」より前にない")
    end

    it "special であるべき観点の手順が basic なら NG" do
      response = Llm::FakeClient::DEFAULT_RESPONSE.deep_dup
      response[:subtasks][0] = response[:subtasks][0].merge(kind: "basic")
      result = score(estimate, response)

      expect(check_named(result, "仕入れ先への依頼", category: :aspect)).to be_ok
      expect(check_named(result, "仕入れ先への依頼", category: :special))
        .to have_attributes(ok: false, reason: "1 件目が basic")
    end

    it "期限が現在より前・親の期限より後・欠落・解釈不能なら期限の範囲が NG" do
      response = { subtasks: [
        subtask("仕入れ先に見積もりを依頼する", kind: "special", due_at: "2026-10-26T08:00:00+09:00"),
        subtask("見積書を作成する", due_at: "2026-10-26T18:00:00+09:00"),
        subtask("見積書を確認する", due_at: nil),
        subtask("見積書を提出する", due_at: "あした")
      ] }

      expect(check_named(score(estimate, response), "期限の範囲")).to have_attributes(
        ok: false,
        reason: include(
          "1 件目が現在より前（10/26 08:00）",
          "2 件目が親の期限より後（10/26 18:00）",
          "3 件目に期限がない",
          "4 件目の期限を解釈できない",
          "範囲: 10/26 09:00〜10/26 17:00"
        )
      )
    end

    it "期限の下限は評価時刻の 1 分前まで許容し、それより前は NG（現在時刻を分単位に丸めた応答を誤判定しない）" do
      now_with_seconds = Time.zone.parse("2026-10-26 09:00:45")
      response_with_first_due = lambda do |due_at|
        { subtasks: [
          subtask("仕入れ先に見積もりを依頼する", kind: "special", due_at: due_at),
          subtask("見積書を作成する", due_at: "2026-10-26T16:00:00+09:00"),
          subtask("見積書を提出する", due_at: "2026-10-26T17:00:00+09:00")
        ] }
      end
      score_at = ->(due_at) { described_class.new(eval_case: estimate, response: response_with_first_due.call(due_at), now: now_with_seconds).call }

      expect(check_named(score_at.call("2026-10-26T09:00:00+09:00"), "期限の範囲")).to be_ok
      expect(check_named(score_at.call("2026-10-26T08:59:45+09:00"), "期限の範囲")).to be_ok
      expect(check_named(score_at.call("2026-10-26T08:59:44+09:00"), "期限の範囲"))
        .to have_attributes(ok: false, reason: include("1 件目が現在より前（10/26 08:59）"))
    end

    it "上司の承認は「上司に相談」「上司へ相談」でも該当する" do
      %w[上司に相談して進め方を決める 上司へ相談して了解を得る].each do |title|
        response = { subtasks: [ subtask(title, kind: "special") ] }
        expect(check_named(score(proposal, response), "上司の承認", category: :special)).to be_ok
      end
    end

    it "期限が実行順に並んでいなければ期限の順序が NG" do
      response = { subtasks: [
        subtask("仕入れ先に見積もりを依頼する", kind: "special", due_at: "2026-10-26T15:00:00+09:00"),
        subtask("見積書を作成する", due_at: "2026-10-26T13:00:00+09:00"),
        subtask("見積書を提出する", due_at: "2026-10-26T17:00:00+09:00")
      ] }
      result = score(estimate, response)

      expect(check_named(result, "期限の範囲")).to be_ok
      expect(check_named(result, "期限の順序"))
        .to have_attributes(ok: false, reason: "1 件目（10/26 15:00）が 2 件目（10/26 13:00）より後")
    end
  end
end
