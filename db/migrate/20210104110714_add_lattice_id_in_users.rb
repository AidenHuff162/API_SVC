class AddLatticeIdInUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :lattice_id, :string
  end
end
