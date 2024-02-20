class AddVisibilityToUser < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :visibility, :boolean, default: true
  end
end
