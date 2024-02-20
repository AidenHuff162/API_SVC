class AddSyncPreferredNameColumnInIntegrations < ActiveRecord::Migration[5.1]
  def change
  	add_column :integrations, :sync_preferred_name, :boolean, default: false
  end
end
