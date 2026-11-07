# frozen_string_literal: true

require "yaml"

module Evals
  # AI 評価セットの 1 事例（spec/evals/cases/<name>.yml）
  # 入力（タイトル・補足・期限）と期待値を持つ。期限は評価時刻からの相対（due_in）で書く
  class EvalCase
    CASES_DIR = Rails.root.join("spec/evals/cases")
    DURATION_FORMAT = /\A(\d+)\s*([mhd])\z/
    DURATION_UNITS = { "m" => :minutes, "h" => :hours, "d" => :days }.freeze

    attr_reader :name, :label, :title, :description, :due_in, :expectation

    class << self
      # 事例名の一覧（ファイル名順）
      def names(dir: CASES_DIR)
        Dir.glob(File.join(dir, "*.yml")).map { |path| File.basename(path, ".yml") }.sort
      end

      def all(dir: CASES_DIR)
        names(dir: dir).map { |name| load(name, dir: dir) }
      end

      # @raise [ArgumentError] 事例が存在しないとき
      def load(name, dir: CASES_DIR)
        path = File.join(dir, "#{name}.yml")
        unless File.basename(name.to_s) == name.to_s && File.exist?(path)
          raise ArgumentError, "評価事例が見つかりません: #{name}（#{names(dir: dir).join(' / ')}）"
        end

        new(name: name.to_s, **YAML.safe_load_file(path).symbolize_keys)
      end

      # "8h" / "3d" / "30m" を秒数（ActiveSupport::Duration）にする
      def parse_duration(value)
        match = DURATION_FORMAT.match(value.to_s.strip)
        raise ArgumentError, "due_in の形式が不正です（例: 8h / 3d / 30m）: #{value.inspect}" unless match

        match[1].to_i.public_send(DURATION_UNITS.fetch(match[2]))
      end
    end

    def initialize(name:, title:, label: nil, description: nil, due_in: nil, expect: {})
      @name = name
      @label = label || name
      @title = title
      @description = description
      @due_in = due_in
      @expectation = expect.deep_stringify_keys
      self.class.parse_duration(due_in) if due_in.present? # 形式を早めに検証する
    end

    # 評価時刻から見た親タスクの期限（due_in が無ければ nil）
    def due_at(now)
      return nil if due_in.blank?

      now + self.class.parse_duration(due_in)
    end

    def count_range
      count = expectation.fetch("count", {})
      (count.fetch("min", 3).to_i)..(count.fetch("max", 8).to_i)
    end

    # [{ "name" => "...", "keywords" => [...] }, ...]
    def aspects
      expectation.fetch("aspects", [])
    end

    # [["観点A", "観点B", ...], ...]
    def order_chains
      expectation.fetch("order", [])
    end

    def special_aspects
      expectation.fetch("special", [])
    end
  end
end
