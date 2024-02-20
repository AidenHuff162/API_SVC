class AddSelectedApiKeyFieldsToApiKeys < ActiveRecord::Migration[6.0]
  def change
    add_column :api_keys, :selected_api_key_fields, :jsonb, default: {}
  end
end
