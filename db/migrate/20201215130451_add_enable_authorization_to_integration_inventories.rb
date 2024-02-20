class AddEnableAuthorizationToIntegrationInventories < ActiveRecord::Migration[5.1]
  def change
     add_column :integration_inventories, :enable_authorization, :boolean, default: false
  end
end
