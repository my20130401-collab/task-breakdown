# frozen_string_literal: true

module Evals
  # AI の分解結果（Llm クライアントの decompose の戻り値）を評価事例の期待値でルールベース採点する
  # 外部通信・DB 保存を行わない純粋なクラス
  class DecompositionScorer
    # 採点項目 1 件の結果
    Check = Data.define(:category, :name, :ok, :reason) do
      def ok? = ok
    end

    # 事例 1 件の採点結果
    Result = Data.define(:eval_case, :checks) do
      def passed? = checks.all?(&:ok?)
      def failures = checks.reject(&:ok?)
    end

    # @param eval_case [Evals::EvalCase]
    # @param response [Hash] { subtasks: [{ title:, kind:, due_at:, ... }] }（キーは文字列・シンボルどちらでもよい）
    # @param now [Time] 評価時刻（プロンプトに渡した現在日時）
    def initialize(eval_case:, response:, now:)
      @eval_case = eval_case
      @subtasks = Array((response || {}).deep_symbolize_keys[:subtasks])
      @now = now
      @parent_due_at = eval_case.due_at(now)
    end

    def call
      checks = [ count_check ]
      checks.concat(aspect_checks)
      checks.concat(order_checks)
      checks.concat(special_checks)
      checks << due_range_check
      checks << due_order_check
      Result.new(eval_case: @eval_case, checks: checks)
    end

    private

    attr_reader :subtasks

    def count_check
      range = @eval_case.count_range
      check(:count, "件数", range.cover?(subtasks.size), "#{subtasks.size} 件（期待: #{range.min}〜#{range.max} 件）")
    end

    def aspect_checks
      @eval_case.aspects.map do |aspect|
        indexes = matching_indexes(aspect["name"])
        if indexes.any?
          check(:aspect, aspect["name"], true, "#{indexes.first + 1} 件目「#{subtasks[indexes.first][:title]}」")
        else
          check(:aspect, aspect["name"], false, "該当する手順がない（キーワード: #{Array(aspect['keywords']).join(' / ')}）")
        end
      end
    end

    # 列の隣り合う観点 A → B について、A の手順のどれかが B の手順のどれかより前にあること
    def order_checks
      @eval_case.order_chains.map do |chain|
        name = chain.join(" → ")
        broken = chain.each_cons(2).find do |before, after|
          before_indexes = matching_indexes(before)
          after_indexes = matching_indexes(after)
          before_indexes.empty? || after_indexes.empty? || before_indexes.min >= after_indexes.max
        end

        if broken
          missing = broken.find { |aspect_name| matching_indexes(aspect_name).empty? }
          reason = missing ? "「#{missing}」の手順がない" : "「#{broken[0]}」が「#{broken[1]}」より前にない"
          check(:order, name, false, reason)
        else
          check(:order, name, true, "順序どおり")
        end
      end
    end

    def special_checks
      @eval_case.special_aspects.map do |aspect_name|
        indexes = matching_indexes(aspect_name)
        special_index = indexes.find { |index| subtasks[index][:kind].to_s == "special" }

        if special_index
          check(:special, aspect_name, true, "#{special_index + 1} 件目が special")
        elsif indexes.empty?
          check(:special, aspect_name, false, "該当する手順がない")
        else
          check(:special, aspect_name, false, "#{indexes.map { |i| "#{i + 1} 件目" }.join('・')}が basic")
        end
      end
    end

    # 各サブタスクの期限が「評価時刻〜親の期限」に収まること（親に期限がなければ下限だけ見る）
    def due_range_check
      problems = parsed_due_ats.each_with_index.filter_map do |due_at, index|
        label = "#{index + 1} 件目"
        if due_at == :missing
          "#{label}に期限がない"
        elsif due_at == :invalid
          "#{label}の期限を解釈できない"
        elsif due_at < @now
          "#{label}が現在より前（#{format_time(due_at)}）"
        elsif @parent_due_at && due_at > @parent_due_at
          "#{label}が親の期限より後（#{format_time(due_at)}）"
        end
      end

      range = "#{format_time(@now)}〜#{@parent_due_at ? format_time(@parent_due_at) : '期限なし'}"
      if subtasks.empty?
        check(:due, "期限の範囲", false, "サブタスクがない")
      elsif problems.empty?
        check(:due, "期限の範囲", true, "すべて #{range} の範囲内")
      else
        check(:due, "期限の範囲", false, "#{problems.join('、')}（範囲: #{range}）")
      end
    end

    # 期限が実行順（前の手順の期限 <= 後の手順の期限）に並ぶこと。期限がない・解釈できない手順は比べない
    def due_order_check
      times = parsed_due_ats.each_with_index.select { |due_at, _| due_at.is_a?(Time) }
      broken = times.each_cons(2).find { |(earlier, _), (later, _)| earlier > later }

      if times.size < 2 && subtasks.size >= 2
        check(:due, "期限の順序", false, "比べられる期限が 2 件未満")
      elsif broken
        (earlier, earlier_index), (later, later_index) = broken
        check(:due, "期限の順序", false,
              "#{earlier_index + 1} 件目（#{format_time(earlier)}）が #{later_index + 1} 件目（#{format_time(later)}）より後")
      else
        check(:due, "期限の順序", true, "実行順に並んでいる")
      end
    end

    # タイトルが観点のキーワードのどれかを含むサブタスクの位置（0 始まり）
    def matching_indexes(aspect_name)
      aspect = @eval_case.aspects.find { |a| a["name"] == aspect_name }
      raise ArgumentError, "評価事例に未定義の観点です: #{aspect_name}" unless aspect

      keywords = Array(aspect["keywords"])
      subtasks.each_index.select do |index|
        title = subtasks[index][:title].to_s
        keywords.any? { |keyword| title.include?(keyword) }
      end
    end

    def parsed_due_ats
      @parsed_due_ats ||= subtasks.map do |subtask|
        raw = subtask[:due_at]
        next :missing if raw.blank?

        Time.zone.iso8601(raw.to_s)
      rescue ArgumentError
        :invalid
      end
    end

    def format_time(time)
      time.in_time_zone.strftime("%m/%d %H:%M")
    end

    def check(category, name, ok, reason)
      Check.new(category: category, name: name, ok: ok, reason: reason)
    end
  end
end
