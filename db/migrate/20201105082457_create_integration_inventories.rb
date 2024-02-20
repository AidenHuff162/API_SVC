class CreateIntegrationInventories < ActiveRecord::Migration[5.1]
  def change
    create_table :integration_inventories do |t|
      t.string :display_name, null: false
      t.integer :status, null: false
      t.integer :category, null: false
      t.string :knowledge_base_url
      t.integer :data_direction
      t.boolean :enable_filters, null: false, default: false
      t.boolean :enable_test_sync, null: false, default: false
      t.integer :state, null: false, default: 1
      t.integer :position, null: false, default: 0
      t.boolean :enable_multiple_instance, null: false, default: false
      t.string :api_identifier, null: false
      t.timestamps null: false
    end
  end
end
