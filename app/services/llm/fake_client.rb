module Llm
  # テストや開発環境で利用するダミークライアント
  # 外部通信を行わず、docs/ai-decomposition.md に記載された固定形式の JSON を即座に返します
  class FakeClient
    # 固定で返却するサブタスクのサンプルデータ
    DEFAULT_RESPONSE = {
      subtasks: [
        {
          title: "仕入れ先に見積もりを依頼する",
          description: "15時までに依頼し、当日中に回答をもらう",
          kind: "special",
          estimated_minutes: 15,
          due_at: "2026-10-26T15:00:00+09:00"
        },
        {
          title: "見積書を作成する",
          description: "仕入れ先からの回答をもとに作成する",
          kind: "basic",
          estimated_minutes: 30,
          due_at: "2026-10-26T16:00:00+09:00"
        },
        {
          title: "見積書を提出する",
          description: "メールで送付し、電話で到着確認をする",
          kind: "basic",
          estimated_minutes: 15,
          due_at: "2026-10-26T17:00:00+09:00"
        }
      ]
    }.freeze

    # 分解を実行するメソッド（インターフェース）
    # 期限は DEFAULT_RESPONSE の間隔を保ったまま、最初の手順が現在時刻の 1 時間後になるようにずらす
    # （固定日時のままだと日が経つと過去になり、期限なしとして保存されてしまうため）
    # @param prompt [String] プロンプト文字列（Fake では内容は無視して固定値を返す）
    # @param current_time [Time] 期限をずらす基準の現在時刻
    # @param options [Hash] オプション引数
    # @return [Hash] パース済みのレスポンス（シンボルキーの Hash）
    def decompose(prompt:, current_time: Time.current, **_options)
      { subtasks: rebase_due_ats(DEFAULT_RESPONSE[:subtasks], current_time) }
    end

    private

    def rebase_due_ats(subtasks, current_time)
      base = Time.zone.iso8601(subtasks.first[:due_at])
      start = current_time.in_time_zone.change(sec: 0) + 1.hour

      subtasks.map do |subtask|
        offset = Time.zone.iso8601(subtask[:due_at]) - base
        subtask.merge(due_at: (start + offset).iso8601)
      end
    end
  end
end
