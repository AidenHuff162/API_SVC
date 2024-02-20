class AddWebhookKeyToWebhook < ActiveRecord::Migration[5.1]
  def change
    add_column :webhooks, :zapier, :boolean, default: false
    change_column_null :webhooks, :target_url, true
    add_column :webhooks, :webhook_key, :string
  end
end
