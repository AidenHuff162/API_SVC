class RemoveColumnsFromUserRoles < ActiveRecord::Migration[5.1]
  def change
  	remove_column :user_roles, :is_account_owner, :boolean
  	remove_column :user_roles, :temp_team_permission_level, :integer
  	remove_column :user_roles, :temp_location_permission_level, :integer
  	remove_column :user_roles, :temp_status_permission_level, :integer
  end
end
