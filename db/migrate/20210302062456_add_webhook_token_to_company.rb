class AddWebhookTokenToCompany < ActiveRecord::Migration[5.1]
  def change
    add_column :companies, :encrypted_webhook_token, :string
    add_column :companies, :encrypted_webhook_token_iv, :string
  end
end
