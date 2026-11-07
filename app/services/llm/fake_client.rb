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
    # @param prompt [String] プロンプト文字列（Fake では内容は無視して固定値を返す）
    # @param options [Hash] オプション引数
    # @return [Hash] パース済みのレスポンス（シンボルキーの Hash）
    def decompose(prompt:, **_options)
      DEFAULT_RESPONSE
    end
  end
end
