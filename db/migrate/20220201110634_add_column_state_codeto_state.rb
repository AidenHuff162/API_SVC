class AddColumnStateCodetoState < ActiveRecord::Migration[5.1]
  def change
    add_column :states, :state_codes, :json, default: {}
  end
end
