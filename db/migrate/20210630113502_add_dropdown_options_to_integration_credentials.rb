class AddDropdownOptionsToIntegrationCredentials < ActiveRecord::Migration[5.1]
  def change
    add_column :integration_credentials, :dropdown_options, :jsonb
  end
end
