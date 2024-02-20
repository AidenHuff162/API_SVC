class AddTypeKeyTypeToApiKeys < ActiveRecord::Migration[5.1]
  def change
    add_column :api_keys, :api_key_type, :integer, default: 0
  end
end
