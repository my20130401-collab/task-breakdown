# frozen_string_literal: true

class TasksController < ApplicationController
  include DueDateHelper

  # 編集・更新・削除・詳細表示・再分解の前に、対象のタスクを探しておく共通処理
  before_action :set_task, only: %i[show edit update destroy redecompose]

  # マイタスク一覧（S-5）の表示
  def index
    tasks = Current.user.tasks.roots.ordered_by_due.includes(:children)
    @grouped_tasks = tasks.group_by { |task| due_label(task.due_at, date_only: true) }
  end

  # タスク詳細画面（S-4）の表示
  def show
  end

  # タスク作成画面（S-3）の表示
  def new
    @task = Task.new
  end

  # タスク作成の保存処理
  def create
    @task = Current.user.tasks.build(task_params)

    if @task.save
      # 1. AI 分解履歴（分解中: pending）を作成
      @task.decompositions.create!(status: :pending, request_payload: { prompt: @task.title })
      # 2. 非同期ジョブをキューに登録（裏側で実行）
      DecomposeTaskJob.perform_later(@task.id)

      # 3. 作成されたタスクの詳細画面（S-4）へリダイレクト
      redirect_to task_path(@task), notice: t(".success")
    else
      flash.now[:alert] = t(".failure")
      render :new, status: :unprocessable_entity
    end
  end

  # 再分解アクション（失敗時や再実行ボタンから呼ばれる）
  def redecompose
    @task.decompositions.create!(status: :pending, request_payload: { prompt: @task.title })
    DecomposeTaskJob.perform_later(@task.id)

    redirect_to task_path(@task)
  end

  # タスク編集画面の表示
  def edit
  end

  # タスク編集の保存処理
  def update
    if @task.update(task_params)
      redirect_to tasks_path, notice: t(".success")
    else
      flash.now[:alert] = t(".failure")
      render :edit, status: :unprocessable_entity
    end
  end

  # タスクの削除処理
  def destroy
    @task.destroy
    redirect_to tasks_path, notice: t(".success"), status: :see_other
  end

  private

  # 防犯対策：自分のタスクの中からだけ探す
  def set_task
    @task = Current.user.tasks.find(params[:id])
  end

  def task_params
    params.expect(task: [ :title, :due_at ])
  end
end
