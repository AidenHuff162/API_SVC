class DropRemoveAccessTypeToUser < ActiveRecord::Migration[5.1]
  def change
    remove_column :users, :remove_access_state, :integer
  end
end
