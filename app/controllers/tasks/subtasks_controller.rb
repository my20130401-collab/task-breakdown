module Tasks
  class SubtasksController < ApplicationController
    before_action :set_parent_task
    before_action :set_subtask, only: %i[show edit update destroy]

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

    def new
      @subtask = @task.children.build
      @subtask.user = Current.user # Userのバリデーションエラーを回避
    end

    def create
      @subtask = @task.children.build(subtask_params)
      @subtask.user = Current.user # Userのバリデーションエラーを回避

      if @subtask.save
        @number = @task.children.ordered_by_due.pluck(:id).index(@subtask.id).to_i + 1
        # 成功時は create.turbo_stream.erb がレンダリングされます
      else
        # 失敗時はフォームを再描画する
        render turbo_stream: turbo_stream.replace(
          "new_subtask_form",
          partial: "form",
          locals: { task: @task, subtask: @subtask }
        ), status: :unprocessable_entity
      end
    end

    def edit
    end

    def show
      # キャンセル時に元のパーシャルを再レンダリングするため
      @number = @task.children.ordered_by_due.pluck(:id).index(@subtask.id).to_i + 1
    end

    def update
      if @subtask.update(subtask_params)
        @number = @task.children.ordered_by_due.pluck(:id).index(@subtask.id).to_i + 1
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
      # params[:task] が存在しない（空のまま保存された等）場合でもエラーにせず、空のパラメータを返す
      if params[:task].present?
        params.require(:task).permit(:title, :description)
      else
        ActionController::Parameters.new(title: "").permit(:title, :description)
      end
    end
  end
end
