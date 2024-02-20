class AddIntegrationCredentialsIdToApiKey < ActiveRecord::Migration[5.1]
  def change
    add_column :api_keys, :integration_credential_id, :integer
  end
end
