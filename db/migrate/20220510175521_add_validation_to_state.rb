class AddValidationToState < ActiveRecord::Migration[5.1]
  def change
    change_column_null(:users, :state, false, 'active')
  end
end
