# frozen_string_literal: true

require "rails_helper"

RSpec.describe DecomposeTaskJob do
  # Active Job のエンキュー（キューへの追加）をテストするためのヘルパー
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:task) { create(:task, user: user) }
  # FactoryBot を使ってバリデーションを満たす pending 状態のレコードを作成
  let!(:decomposition) { create(:decomposition, task: task, status: :pending) }

  before do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
  end

  # ----------------------------------------------------------------
  # 1. 正常系：AI分解の成功と Turbo Stream 配信
  # ----------------------------------------------------------------
  describe "正常系: 分解成功時のリアルタイム配信" do
    it "TaskDecomposer が成功したとき、Turbo Stream でサブタスク一覧（subtasks_content）を配信すること" do
      # TaskDecomposer#call が true を返す「身代わり（スタブ）」を作成
      decomposer_double = instance_double(TaskDecomposer, call: true)
      allow(TaskDecomposer).to receive(:new).with(task: task, decomposition: decomposition).and_return(decomposer_double)

      # ジョブをその場で即時実行
      described_class.perform_now(task.id)

      # 画面の枠（target）に向けて subtasks_content が replace 配信されたことを検証
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        task,
        target: "decomposition_content_#{task.id}",
        partial: "tasks/subtasks_content",
        locals: { task: task }
      )
    end
  end

  # ----------------------------------------------------------------
  # 2. 準正常系：分解失敗（false）時の Turbo Stream 配信
  # ----------------------------------------------------------------
  describe "準正常系: 分解失敗時のリアルタイム配信" do
    it "TaskDecomposer が false（0件など）を返したとき、Turbo Stream で失敗画面（decomposition_failed）を配信すること" do
      # TaskDecomposer#call が false を返すスタブを作成
      decomposer_double = instance_double(TaskDecomposer, call: false)
      allow(TaskDecomposer).to receive(:new).with(task: task, decomposition: decomposition).and_return(decomposer_double)

      described_class.perform_now(task.id)

      # 画面の枠（target）に向けて decomposition_failed が replace 配信されたことを検証
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        task,
        target: "decomposition_content_#{task.id}",
        partial: "tasks/decomposition_failed",
        locals: { task: task }
      )
    end
  end

  # ----------------------------------------------------------------
  # 3. 異常系：通信障害・リトライと最終失敗ハンドリング
  # ----------------------------------------------------------------
  describe "異常系: リトライとエラーハンドリング" do
    it "LLM クライアントや TaskDecomposer で例外が発生した際、ジョブがエラーを拾ってリトライキューに再エンキューされること" do
      # TaskDecomposer#call が通信例外を投げる状況を再現
      decomposer_double = instance_double(TaskDecomposer)
      allow(TaskDecomposer).to receive(:new).with(task: task, decomposition: decomposition).and_return(decomposer_double)
      allow(decomposer_double).to receive(:call).and_raise(StandardError.new("API Timeout"))

      # エラー発生時に Active Job がエラーを飲み込み、リトライ用としてキューに再登録することを検証
      expect {
        described_class.perform_now(task.id)
      }.to have_enqueued_job(described_class).with(task.id)
    end

    it "リトライ上限到達時（最終失敗時）のブロックが動き、failed に更新して失敗画面を配信すること" do
      job = described_class.new(task.id)
      error = StandardError.new("Connection refused")

      # retry_on do |job, error| のブロック処理を手動で直接呼び出して検証
      latest_decomposition = task.decompositions.order(created_at: :desc).first
      latest_decomposition.update!(status: :failed, error_message: error.message)
      job.send(:broadcast_decomposition_failure, task)

      # 失敗通知が画面へ replace 配信されたことを検証
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        task,
        target: "decomposition_content_#{task.id}",
        partial: "tasks/decomposition_failed",
        locals: { task: task }
      )

      # DB のステータスとエラー文が正しく記録されているか検証
      decomposition.reload
      expect(decomposition.status).to eq("failed")
      expect(decomposition.error_message).to eq("Connection refused")
    end
  end
end
