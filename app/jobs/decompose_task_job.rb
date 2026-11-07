# frozen_string_literal: true

# タスクの AI 分解を非同期で実行し、結果を Turbo Stream で画面へ配信するジョブ
class DecomposeTaskJob < ApplicationJob
  queue_as :default

  # 通信障害やタイムアウト時、2 秒待って最大 2 回リトライ（合計 3 回実行）
  retry_on StandardError, wait: 2.seconds, attempts: 3 do |job, error|
    task_id = job.arguments.first
    task = Task.find_by(id: task_id)
    next unless task

    decomposition = task.latest_decomposition
    decomposition&.update!(status: :failed, error_message: error.message)

    job.send(:broadcast_decomposition_failure, task)
  end

  def perform(task_id)
    task = Task.find(task_id)
    decomposition = task.decompositions.pending.latest_first.first || task.decompositions.build

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
    broadcast_result(task, status: :done, partial: "tasks/subtasks_content")
  end

  def broadcast_decomposition_failure(task)
    broadcast_result(task, status: :failed, partial: "tasks/decomposition_failed")
  end

  # 分解エリアの中身（update: 枠の id を残し、再分解後も同じ枠に配信できるようにする）と、
  # 見出し上の分解ステータス・進捗をあわせて更新する
  def broadcast_result(task, status:, partial:)
    task.reload
    Turbo::StreamsChannel.broadcast_update_to(
      task,
      target: "decomposition_content_#{task.id}",
      partial: partial,
      locals: { task: task }
    )
    Turbo::StreamsChannel.broadcast_update_to(
      task,
      target: "decomposition_status_#{task.id}",
      partial: "shared/decomposition_status",
      locals: { status: status }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      task,
      target: "task_progress_#{task.id}",
      partial: "tasks/progress",
      locals: { task: task }
    )
  end
end
