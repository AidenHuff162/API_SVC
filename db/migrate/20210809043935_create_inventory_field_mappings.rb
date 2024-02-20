class CreateInventoryFieldMappings < ActiveRecord::Migration[5.1]
  def change
    create_table :inventory_field_mappings do |t|
      t.string :inventory_field_key
      t.string :inventory_field_name
      t.references :integration_inventory, foreign_key: true, index:  true
    end
  end
end
