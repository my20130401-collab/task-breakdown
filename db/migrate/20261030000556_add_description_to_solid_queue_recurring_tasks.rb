class AddDescriptionToSolidQueueRecurringTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :solid_queue_recurring_tasks, :description, :text
  end
end
