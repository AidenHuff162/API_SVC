class CreateIntegrationConfigurations < ActiveRecord::Migration[5.1]
  def change
    create_table :integration_configurations do |t|
      t.integer :category, null: false
      t.string :field_name
      t.string :field_type
      t.string :toggle_context
      t.string :toggle_identifier
      t.string :dropdown_options
      t.string :vendor_domain
      t.string :width
      t.string :help_text
      t.boolean :is_required, null: false, default: true
      t.boolean :is_visible, null: false, default: true
      t.integer :position
      t.boolean :is_encrypted, null: false, default: false
      t.references :integration_inventory, foreign_key: true, index: true
      t.timestamps null: false
    end
  end
end
