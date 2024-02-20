class AddIntegrationSelectedOption < ActiveRecord::Migration[5.1]
  def change
    add_column :integration_field_mappings, :integration_selected_option, :jsonb
  end
end
