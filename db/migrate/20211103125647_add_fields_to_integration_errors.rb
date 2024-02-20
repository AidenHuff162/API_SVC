class AddFieldsToIntegrationErrors < ActiveRecord::Migration[5.1]
  def change
    add_column :integration_error_slack_webhooks, :event_type, :integer, default: 0
    add_column :integration_error_slack_webhooks, :integration_name, :string
    add_column :integration_error_slack_webhooks, :company_name, :string
  end
end
