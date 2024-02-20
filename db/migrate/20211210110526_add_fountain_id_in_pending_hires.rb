class AddFountainIdInPendingHires < ActiveRecord::Migration[5.1]
  def change
    add_column :pending_hires, :fountain_id, :string
  end
end
