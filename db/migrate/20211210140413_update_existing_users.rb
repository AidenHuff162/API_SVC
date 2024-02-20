class UpdateExistingUsers < ActiveRecord::Migration[5.1]
  def change
    unless ActiveRecord::Base.connection.column_exists?(:users, :remove_access_state)
      add_column :users, :remove_access_state, :integer, default: 0
    end
    User.where(current_stage: :departed, state: :inactive).update_all(remove_access_state: 1)
  end
end
