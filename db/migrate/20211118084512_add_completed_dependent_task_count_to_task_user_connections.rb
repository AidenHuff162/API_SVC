class AddCompletedDependentTaskCountToTaskUserConnections < ActiveRecord::Migration[5.1]
  def change
    add_column :task_user_connections, :completed_dependent_task_count, :integer, null: false, default: 0
  end
end
