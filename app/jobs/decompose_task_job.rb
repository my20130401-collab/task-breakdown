# frozen_string_literal: true

# タスクの AI 分解を非同期で実行し、結果を Turbo Stream で画面へ配信するジョブ
class DecomposeTaskJob < ApplicationJob
  queue_as :default

  # 一時的なネットワークエラーやレート制限の場合、最大 2 回リトライ
  retry_on StandardError, wait: 2.seconds, attempts: 3 do |job, error|
    # リトライ回数を使い切った場合の最終失敗処理
    task_id = job.arguments.first
    task = Task.find_by(id: task_id)
    if task
      decomposition = task.decompositions.order(created_at: :desc).first
      decomposition&.update(status: :failed, error_message: error.message)
      broadcast_decomposition_failure(task)
    end
  end

  # @param task_id [Integer] 分解対象の親タスクID
  def perform(task_id)
    task = Task.find(task_id)
    # 最新の pending な分解履歴を取得、なければ新規作成
    decomposition = task.decompositions.where(status: :pending).order(created_at: :desc).first || task.decompositions.build

    decomposer = TaskDecomposer.new(task: task, decomposition: decomposition)
    success = decomposer.call

    if success
      broadcast_decomposition_success(task)
    else
      broadcast_decomposition_failure(task)
    end
  end

  private

  # 分解成功時：Turbo Stream でタスク詳細画面のサブタスク一覧とステータスを更新
  def broadcast_decomposition_success(task)
    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "decomposition_content_#{task.id}",
      partial: "tasks/subtasks_content",
      locals: { task: task }
    )
  end

  # 分解失敗時：Turbo Stream でエラーメッセージと再実行ボタンを表示
  def broadcast_decomposition_failure(task)
    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "decomposition_content_#{task.id}",
      partial: "tasks/decomposition_failed",
      locals: { task: task }
    )
  end
end
