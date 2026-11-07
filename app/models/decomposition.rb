class Decomposition < ApplicationRecord
  # 関連付け
  # どの親タスクに対するAI分解履歴かを紐付ける（task_id が必須）
  belongs_to :task

  # 列挙型（Enum）
  # 処理ステータス（0: 分解中, 1: 成功, 2: 失敗）
  enum :status, {
    pending: 0,
    succeeded: 1,
    failed: 2
  }

  # 分解の粒度（0: 通常 3〜8件, 1: 細かく 6〜12件, 2: ざっくり 2〜4件）
  enum :granularity, {
    normal: 0,
    finer: 1,
    coarser: 2
  }

  # スコープ
  # 新しい順。作成日時が同じ（同じ秒に作った・テストで時刻を止めた）ときは、後から作った（id が大きい）方を先にする
  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  # バリデーション
  # 空欄のまま保存されて意図しない不整合が起きないよう防ぐ
  validates :status, presence: true
  validates :granularity, presence: true
  validates :request_payload, presence: true
end
