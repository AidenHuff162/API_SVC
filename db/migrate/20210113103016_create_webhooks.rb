class CreateWebhooks < ActiveRecord::Migration[5.1]
  def change
    create_table :webhooks do |t|
      t.integer :event, null: false
      t.integer :state, default: 0
      t.integer :created_from, default: 0

      t.string :target_url, null: false
      t.string :description
      t.string :guid
      t.string :created_by_reference
      t.string :updated_by_reference
      
      t.json :filters
      
      t.references :created_by, foreign_key: { to_table: 'users' }, index:  true
      t.references :updated_by, foreign_key: { to_table: 'users' }, index:  true
      t.references :company, foreign_key: true, index: true

      t.timestamps
    end
  end
end