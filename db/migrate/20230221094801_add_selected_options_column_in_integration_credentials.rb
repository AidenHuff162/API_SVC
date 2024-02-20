class AddSelectedOptionsColumnInIntegrationCredentials < ActiveRecord::Migration[6.0]
  def change
    add_column :integration_credentials, :selected_options, :jsonb
  end
end
