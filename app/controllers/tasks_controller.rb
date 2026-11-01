class TasksController < ApplicationController
  include DueDateHelper

  # 編集・更新・削除の前に、対象のタスクをあらかじめ探しておく共通処理
  before_action :set_task, only: %i[edit update destroy]

  # マイタスク一覧（S-5）の表示
  def index
    # ログイン中ユーザーの親タスクを期限順で取得
    tasks = Current.user.tasks.roots.ordered_by_due.includes(:children)

    # 日付見出しごと（今日・明日・M/D・期限なし）にグループ化
    @grouped_tasks = tasks.group_by { |task| due_label(task.due_at, date_only: true) }
  end

  # タスク作成画面（S-3）の表示
  def new
    @task = Task.new
  end

  # タスク作成の保存処理
  def create
    @task = Current.user.tasks.build(task_params)

    if @task.save
      redirect_to task_detail_mock_path, notice: t(".success")
    else
      flash.now[:alert] = t(".failure")
      render :new, status: :unprocessable_entity
    end
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
