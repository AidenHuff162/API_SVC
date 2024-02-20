class AddDependentTasksToTasks < ActiveRecord::Migration[5.1]
  def change
    add_column :tasks, :dependent_tasks, :integer, array: true, default: []
  end
end
