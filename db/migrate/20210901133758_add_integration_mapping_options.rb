class AddIntegrationMappingOptions < ActiveRecord::Migration[5.1]
  def change
    add_column :inventory_field_mappings, :integration_mapping_options, :jsonb
  end
end
