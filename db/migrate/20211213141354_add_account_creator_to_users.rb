class AddAccountCreatorToUsers < ActiveRecord::Migration[5.1]
  def change
  	add_column :users, :account_creator, :boolean, default: false
  end
end
