# frozen_string_literal: true

namespace :eval do
  desc <<~DESC.squish
    AI 分解の評価セット（spec/evals/cases/*.yml）を実行して採点する。
    引数で事例名を指定（例: eval:decompose[estimate]）、省略時は全事例。不合格があれば終了コード 1。
    クライアントは LLM_CLIENT（未指定なら OPENAI_API_KEY の有無）で選ぶ。実 API を使うため CI では実行しない。
    LLM_CLIENT=fake は API キー無しのドライラン用で、固定応答（見積もり作成）を返すため estimate だけが合格し、
    proposal（起案書）と expense（経費申請）は不合格になる。EVAL_VERBOSE=1 で AI の応答（JSON）も出力する。
    DB には保存しない。
  DESC
  task :decompose, [ :case ] => :environment do |_task, args|
    cases =
      begin
        args[:case].present? ? [ Evals::EvalCase.load(args[:case]) ] : Evals::EvalCase.all
      rescue ArgumentError => e
        abort e.message
      end
    passed = Evals::DecomposeRunner.new(
      cases: cases,
      client: Llm::Client.build,
      verbose: ENV["EVAL_VERBOSE"] == "1"
    ).call

    exit 1 unless passed
  end
end
