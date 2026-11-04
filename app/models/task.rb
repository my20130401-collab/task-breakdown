class Task < ApplicationRecord
  # 入力例チップ用の例文
  EXAMPLES = [
    "イベントの企画を進める",
    "資格試験の学習計画を立てる",
    "引っ越しの準備をする"
  ].freeze

  # 関連付け
  belongs_to :user
  belongs_to :parent, class_name: "Task", optional: true
  has_many :children, class_name: "Task", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent

  # 列挙型（Enum）
  enum :kind, { basic: 0, special: 1 }
  enum :status, { todo: 0, done: 1 }
  enum :source, { manual: 0, ai: 1 }

  # バリデーション
  validates :title, presence: true, length: { maximum: 200 }
  validate :due_at_cannot_be_in_the_past
  validate :due_at_cannot_exceed_parent_due_at, if: -> { parent.present? && due_at.present? }
  validate :parent_must_belong_to_same_user, if: -> { parent_id.present? }

  # コールバック（サブタスク保存・削除後に親タスクの状態を同期）
  after_save :sync_parent_status, if: :parent_id?
  after_destroy :sync_parent_status, if: :parent_id?

  # スコープ
  # 親タスクのみ取得（parent_id が nil）
  scope :roots, -> { where(parent_id: nil) }

  # 期限の近い順（未設定は末尾）
  scope :ordered_by_due, -> { order(Arel.sql("due_at ASC NULLS LAST"), :id) }

  # 日付タブ絞り込み用のスコープ（AC-3）
  scope :due_today, -> { where(due_at: Time.zone.now.all_day) }
  scope :due_tomorrow, -> { where(due_at: Time.zone.tomorrow.all_day) }

  # サブタスクの進捗（完了数/全体数）を返す（サブタスクがない場合は nil）
  def progress
    total = children.size
    return nil if total.zero?

    completed = children.count(&:done?)
    { completed: completed, total: total }
  end

  # 完了・未完了の切り替えメソッド
  def complete!
    update!(status: :done, completed_at: Time.current)
  end

  def uncomplete!
    update!(status: :todo, completed_at: nil)
  end

  private

  # 期限は過去日時を指定不可（UC-1, UC-4）
  def due_at_cannot_be_in_the_past
    return if due_at.blank?
    return unless will_save_change_to_due_at?

    if due_at < Time.current.beginning_of_minute
      errors.add(:due_at, :cannot_be_in_the_past)
    end
  end

  # 親タスクの期限を超える日時を設定不可（UC-4）
  def due_at_cannot_exceed_parent_due_at
    return unless parent&.due_at.present?
    return unless will_save_change_to_due_at?

    if due_at > parent.due_at
      errors.add(:due_at, :cannot_exceed_parent_due_at)
    end
  end

  # 親タスクの完了状態を同期する裏方メソッド
  def sync_parent_status
    return unless parent

    children = parent.children.reload
    return if children.empty?

    if children.all?(&:done?)
      parent.update!(status: :done, completed_at: Time.current) unless parent.done?
    else
      parent.update!(status: :todo, completed_at: nil) unless parent.todo?
    end
  end

  # 親子タスクの所有者一致を検証
  def parent_must_belong_to_same_user
    if parent.present? && parent.user_id != user_id
      errors.add(:parent_id, "は同じユーザーのタスクを指定してください")
    end
  end
end
