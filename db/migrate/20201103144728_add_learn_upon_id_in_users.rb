class AddLearnUponIdInUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :learn_upon_id, :string
  end
end
