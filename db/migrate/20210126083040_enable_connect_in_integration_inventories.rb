class EnableConnectInIntegrationInventories < ActiveRecord::Migration[5.1]
  def change
    add_column :integration_inventories, :enable_connect, :boolean, default: false
  end
end
