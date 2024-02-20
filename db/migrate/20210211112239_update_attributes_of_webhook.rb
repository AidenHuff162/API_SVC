class UpdateAttributesOfWebhook < ActiveRecord::Migration[5.1]
  def change
    change_column_default :webhook_events, :status, 2
    change_column :webhooks, :filters, :jsonb

  end
end
