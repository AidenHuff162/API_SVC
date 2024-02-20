class AddMappingDescriptionToIntegrationInventories < ActiveRecord::Migration[5.1]
  def change
    add_column :integration_inventories, :mapping_description, :string
  end
end
