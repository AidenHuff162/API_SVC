class CreateIntegrationInstances < ActiveRecord::Migration[5.1]
  def change
    create_table :integration_instances do |t|
      t.json :filters
      t.json :actions
      t.json :save_for_later
      t.string :api_identifier, null: false
      t.references :integration_inventory, foreign_key: true, index: true
      t.references :company, foreign_key: true, index: true
      t.integer :state, null: false, default: 1
      t.integer :sync_status, default: 0
      t.integer :unsync_records_count
      t.string :name, null: false
      t.datetime :synced_at
      t.timestamps null: false
    end
  end
end
