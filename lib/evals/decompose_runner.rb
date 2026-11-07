# frozen_string_literal: true

require "json"

module Evals
  # 評価事例ごとに AI 分解を実行して採点し、結果の表を出力する（bin/rails eval:decompose の本体）
  # 親タスクは Task.new（未保存）で組み立て、DB には何も保存しない
  class DecomposeRunner
    CATEGORY_LABELS = { count: "件数", aspect: "観点", order: "順序", special: "special", due: "期限" }.freeze

    # @param cases [Array<Evals::EvalCase>]
    # @param client [Object] decompose(prompt:) に応答する LLM クライアント
    # @param out [IO] 出力先
    # @param verbose [Boolean] true なら AI の応答（JSON）も出力する
    # @param now [Time] 評価時刻（プロンプトの現在日時と期限の基準）
    def initialize(cases:, client:, out: $stdout, verbose: false, now: Time.current)
      @cases = cases
      @client = client
      @out = out
      @verbose = verbose
      @now = now
    end

    # @return [Boolean] すべての事例が合格なら true
    def call
      @out.puts "AI 評価セット（クライアント: #{client_name}、評価時刻: #{@now.in_time_zone.strftime('%Y-%m-%d %H:%M')}）"
      results = @cases.map { |eval_case| run_case(eval_case) }
      print_summary(results)
      results.all?
    end

    private

    def run_case(eval_case)
      @out.puts
      @out.puts "== #{eval_case.name}: #{eval_case.label}（#{eval_case.title}、期限: #{eval_case.due_in ? "評価時刻の #{eval_case.due_in} 後" : 'なし'}）"

      response = @client.decompose(prompt: build_prompt(eval_case))
      print_response(response) if @verbose

      result = DecompositionScorer.new(eval_case: eval_case, response: response, now: @now).call
      print_checks(result.checks)
      @out.puts "結果: #{result.passed? ? '合格' : "不合格（NG #{result.failures.size} 件）"}"
      result.passed?
    rescue StandardError => e
      @out.puts "結果: 不合格（分解の実行に失敗: #{e.class}: #{filter_secret(e.message).squish}）"
      false
    end

    # 本番の分解サービスと同じ組み立て（システムプロンプト＋ユーザープロンプト）
    def build_prompt(eval_case)
      task = Task.new(title: eval_case.title, description: eval_case.description, due_at: eval_case.due_at(@now))
      user_prompt = TaskDecomposer::Prompt.build_user_prompt(task, current_time: @now)
      "#{TaskDecomposer::Prompt.system_prompt}\n\n#{user_prompt}"
    end

    def print_checks(checks)
      rows = checks.map do |check|
        [ CATEGORY_LABELS.fetch(check.category), check.name, check.ok? ? "OK" : "NG", check.reason ]
      end
      table = [ %w[区分 項目 判定 理由], *rows ]
      widths = (0..2).map { |i| table.map { |row| display_width(row[i]) }.max }

      table.each do |row|
        cells = row.first(3).each_with_index.map { |cell, i| pad(cell, widths[i]) }
        @out.puts "  #{cells.join(' | ')} | #{row[3]}"
      end
    end

    def print_response(response)
      @out.puts "-- AI の応答"
      @out.puts JSON.pretty_generate(response)
    end

    def print_summary(results)
      @out.puts
      passed = results.count(true)
      @out.puts "合計: #{passed}/#{results.size} 事例が合格"
    end

    def client_name
      @client.class.name
    end

    # API キーが例外メッセージに含まれていても出力しない
    def filter_secret(message)
      key = ENV["OPENAI_API_KEY"]
      key.present? ? message.to_s.gsub(key, "[FILTERED]") : message.to_s
    end

    # 全角文字を 2 桁として数える（表の列をそろえるため。矢印は多くの端末で 1 桁）
    def display_width(text)
      text.to_s.each_char.sum { |char| char.ascii_only? || char == "→" ? 1 : 2 }
    end

    def pad(text, width)
      "#{text}#{' ' * (width - display_width(text))}"
    end
  end
end
