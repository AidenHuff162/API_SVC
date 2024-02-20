class AddConnectedByInIntegrationInstances < ActiveRecord::Migration[5.1]
  def change
    add_reference :integration_instances, :connected_by, index: true, foreign_key: { to_table: :users }
    add_column :integration_instances, :connected_at, :datetime
  end
end
