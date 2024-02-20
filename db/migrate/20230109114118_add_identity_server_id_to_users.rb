class AddIdentityServerIdToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :identity_server_id, :string
  end
end
