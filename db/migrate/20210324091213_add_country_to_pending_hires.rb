class AddCountryToPendingHires < ActiveRecord::Migration[5.1]
  def change
    add_column :pending_hires, :country, :string
  end
end
