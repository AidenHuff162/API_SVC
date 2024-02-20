class AddAppConfigurationSettingInIntegrationErrorWebhook < ActiveRecord::Migration[5.1]
  def change
    add_column :integration_error_slack_webhooks, :configure_app, :integer, default: 0
  end
end
