require "rails_helper"

# 評価コマンド（bin/rails eval:decompose）の本体。外部通信しない固定応答クライアントで確かめる
RSpec.describe Evals::DecomposeRunner do
  let(:out) { StringIO.new }
  let(:client) { Llm::FakeClient.new }

  def run(names, client: self.client, verbose: false)
    cases = names.map { |name| Evals::EvalCase.load(name) }
    described_class.new(cases: cases, client: client, out: out, verbose: verbose).call
  end

  it "固定応答で見積もり作成を採点すると合格し、DB に何も保存しない" do
    expect { expect(run(%w[estimate])).to be true }.not_to change { [ Task.count, Decomposition.count ] }

    expect(out.string).to include(
      "クライアント: Llm::FakeClient", "== estimate", "| 判定 |", "結果: 合格", "合計: 1/1 事例が合格"
    )
    expect(out.string).not_to include("\"subtasks\"")
  end

  it "固定応答で全事例を回すと起案書・経費申請は不合格になり、結果は false" do
    expect(run(Evals::EvalCase.names)).to be false

    expect(out.string.scan("結果: 不合格").size).to eq 2
    expect(out.string).to include("合計: 1/3 事例が合格")
  end

  it "本番と同じシステムプロンプトに、事例のタスクと評価時刻からの期限を渡す" do
    allow(client).to receive(:decompose).and_call_original
    travel_to Time.zone.parse("2026-10-26 09:00") do
      run(%w[estimate])
    end

    expect(client).to have_received(:decompose).with(prompt: include(
      TaskDecomposer::Prompt.system_prompt,
      "【タスク名】: 見積もりを作成する",
      "【親タスクの期限】: 2026-10-26T17:00:00+09:00"
    ))
  end

  it "verbose のときだけ AI の応答（JSON）を出力する" do
    run(%w[estimate], verbose: true)

    expect(out.string).to include("-- AI の応答", "\"title\": \"仕入れ先に見積もりを依頼する\"")
  end

  it "分解に失敗した事例は不合格として続行し、メッセージに API キーを出さない" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("sk-secret")
    failing = instance_double(Llm::OpenAiClient)
    allow(failing).to receive(:decompose).and_raise(RuntimeError, "OpenAI API 通信エラー: key sk-secret")

    expect(run(%w[estimate proposal], client: failing)).to be false
    expect(out.string).to include("分解の実行に失敗: RuntimeError: OpenAI API 通信エラー: key [FILTERED]")
    expect(out.string).not_to include("sk-secret")
    expect(out.string).to include("合計: 0/2 事例が合格")
  end

  it "エラー本文が複数行の JSON でも 1 行に詰めて出力する" do
    failing = instance_double(Llm::OpenAiClient)
    allow(failing).to receive(:decompose)
      .and_raise(RuntimeError, "OpenAI API 通信エラー: HTTP 429 - {\n  \"error\": {\n    \"code\": \"rate_limit\"\n  }\n}")

    run(%w[estimate], client: failing)

    expect(out.string).to include('HTTP 429 - { "error": { "code": "rate_limit" } }）')
  end
end
