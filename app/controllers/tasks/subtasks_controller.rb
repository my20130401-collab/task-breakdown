module Tasks
  class SubtasksController < ApplicationController
    before_action :set_parent_task

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

    private

    def set_parent_task
      @task = Current.user.tasks.find(params[:task_id])
    end
  end
end