# frozen_string_literal: true

# タスクの AI 分解を非同期で実行し、結果を Turbo Stream で画面へ配信するジョブ
class DecomposeTaskJob < ApplicationJob
  queue_as :default

  # 通信障害やタイムアウト時、2 秒待って最大 2 回リトライ（合計 3 回実行）
  retry_on StandardError, wait: 2.seconds, attempts: 3 do |job, error|
    task_id = job.arguments.first
    task = Task.find_by(id: task_id)
    if task
      decomposition = task.decompositions.order(created_at: :desc).first
      decomposition&.update(status: :failed, error_message: error.message)
      broadcast_decomposition_failure(task)
    end
  end

  def perform(task_id)
    task = Task.find(task_id)
    decomposition = task.decompositions.where(status: :pending).order(created_at: :desc).first || task.decompositions.build

    # 頭に :: を付けてトップレベルの TaskDecomposer を確実に参照させる
    decomposer = ::TaskDecomposer.new(task: task, decomposition: decomposition)
    success = decomposer.call

    if success
      broadcast_decomposition_success(task)
    else
      # call が false（0件など）を返した場合の通常失敗処理
      broadcast_decomposition_failure(task)
    end
  end

  private

  def broadcast_decomposition_success(task)
    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "decomposition_content_#{task.id}",
      partial: "tasks/subtasks_content",
      locals: { task: task }
    )
  end

  def broadcast_decomposition_failure(task)
    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "decomposition_content_#{task.id}",
      partial: "tasks/decomposition_failed",
      locals: { task: task }
    )
  end
end
