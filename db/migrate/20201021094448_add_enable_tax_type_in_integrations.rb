class AddEnableTaxTypeInIntegrations < ActiveRecord::Migration[5.1]
  def change
    add_column :integrations, :enable_tax_type, :boolean, default: false
  end
end
