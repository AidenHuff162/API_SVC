class AddDependentTucToTaskUserConnections < ActiveRecord::Migration[5.1]
  def change
    add_column :task_user_connections, :dependent_tuc, :integer, array: true, default: []
  end
end
