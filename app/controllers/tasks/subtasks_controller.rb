module Tasks
  class SubtasksController < ApplicationController
    before_action :set_parent_task
    before_action :set_subtask, only: %i[edit update destroy]

    def index
      # タブごとの絞り込みロジック
      @subtasks = case params[:filter]
      when "today"
                    @task.children.due_today.ordered_by_due
      when "tomorrow"
                    @task.children.due_tomorrow.ordered_by_due
      when "all", nil
                    @task.children.ordered_by_due
      else
                    # M/D などの特定日付の絞り込み
                    target_date = Date.parse(params[:filter]) rescue nil
                    if target_date
                      @task.children.where(due_at: target_date.all_day).ordered_by_due
                    else
                      @task.children.ordered_by_due
                    end
      end
    end

    def create
      # AC-1, AC-2: 空のサブタスクを作成し、直後にインライン編集状態にする
      @subtask = @task.children.create!(title: "") 
      @number = @task.children.count
      # デフォルトで create.turbo_stream.erb がレンダリングされます
    end

    def edit
    end

    def update
      if @subtask.update(subtask_params)
        # update.turbo_stream.erb がレンダリングされます
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @subtask.destroy
      # destroy.turbo_stream.erb がレンダリングされます
    end

    private

    def set_parent_task
      @task = Current.user.tasks.find(params[:task_id])
    end

    def set_subtask
      @subtask = @task.children.find(params[:id])
    end

    def subtask_params
      # 親タスクと同じモデル（Task）を想定
      params.require(:task).permit(:title, :description)
    end
  end
end
