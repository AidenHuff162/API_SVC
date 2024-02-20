class CreateWebhookEvents < ActiveRecord::Migration[5.1]
  def change
    create_table :webhook_events do |t|
      t.integer :status
      t.integer :response_status

      t.string :event_id
      t.string :triggered_by_source
      t.string :triggered_by_reference

      t.json :request_body
      t.json :response_body

      t.boolean :is_test_event, default: :false

      t.references :triggered_for, foreign_key: { to_table: 'users' }, index:  true
      t.references :triggered_by, foreign_key: { to_table: 'users' }, index:  true
      t.references :webhook, foreign_key: true, index: true
      t.references :company, foreign_key: true, index: true

      t.datetime :triggered_at
      
      t.timestamps
    end
  end
end
