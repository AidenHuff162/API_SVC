class AddFieldsToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :new_ui_enabled, :boolean, default: false
    add_column :users, :ui_switcher, :boolean, default: false
  end
end
