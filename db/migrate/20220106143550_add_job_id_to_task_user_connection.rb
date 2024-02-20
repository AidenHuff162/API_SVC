class AddJobIdToTaskUserConnection < ActiveRecord::Migration[5.1]
  def change
    add_column :task_user_connections, :job_id, :string
  end
end
