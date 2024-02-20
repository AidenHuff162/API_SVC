class AddIndexToCustomFieldValues < ActiveRecord::Migration[5.1]
  def change
  	add_index :custom_field_values, [:user_id, :sub_custom_field_id, :deleted_at], unique: true, name: 'index_cfv_on_sub_custom_field_values_and_users'
  end
end
