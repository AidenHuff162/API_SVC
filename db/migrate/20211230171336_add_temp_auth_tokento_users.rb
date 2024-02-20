class AddTempAuthTokentoUsers < ActiveRecord::Migration[5.1]
  def change
  	add_column :users, :temp_auth_token, :string
  end
end
