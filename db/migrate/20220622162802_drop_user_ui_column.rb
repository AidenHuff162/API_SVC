class DropUserUiColumn < ActiveRecord::Migration[5.1]
  def change
    remove_column :users, :new_ui_enabled
  end
end
