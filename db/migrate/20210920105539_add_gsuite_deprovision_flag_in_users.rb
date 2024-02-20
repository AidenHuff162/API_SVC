class AddGsuiteDeprovisionFlagInUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :gsuite_account_deprovisioned, :boolean, default: false
  end
end
