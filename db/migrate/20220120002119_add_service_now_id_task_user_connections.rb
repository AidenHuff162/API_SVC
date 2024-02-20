class AddServiceNowIdTaskUserConnections < ActiveRecord::Migration[5.1]
  def change
    add_column :task_user_connections, :service_now_id, :string
  end
end
