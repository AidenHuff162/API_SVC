class AddMappingFieldsColumnToIntegrationInventories < ActiveRecord::Migration[5.1]
  def change
    add_column :integration_inventories, :field_mapping_option, :integer
    add_column :integration_inventories, :field_mapping_direction, :integer
  end
end
