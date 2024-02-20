class AddGustoIdInUser < ActiveRecord::Migration[5.1]
  def change
  	add_column :users, :gusto_id, :string
  end
end
