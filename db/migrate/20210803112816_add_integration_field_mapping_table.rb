class AddIntegrationFieldMappingTable < ActiveRecord::Migration[5.1]
  def up
  	create_table :integration_field_mappings do |t|
      t.string :integration_field_key
      t.integer  :custom_field_id 
      t.string :preference_field_id
      t.boolean :is_custom
      t.boolean :exclude_in_update
      t.boolean :exclude_in_create
      t.string :parent_hash
      t.string :parent_hash_path
      t.belongs_to :integration_instance
      t.belongs_to :company, index: true
      t.integer :field_position
      t.datetime :created_at
      t.datetime :updated_at

      t.index ["integration_instance_id"], name: "index_integration_field_mapping_on_integration_instance_id"
      t.index ["custom_field_id"], name: "index_integration_field_mapping_on_custom_field_id"
      t.index ['integration_field_key', 'custom_field_id', 'integration_instance_id', 'field_position'], unique: true, name: 'uniqueness_validator'
    end
  end
end
