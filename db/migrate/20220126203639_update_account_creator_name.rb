class UpdateAccountCreatorName < ActiveRecord::Migration[5.1]
  def change
  	rename_column :users, :account_creator, :is_demo_account_creator
  end
end
