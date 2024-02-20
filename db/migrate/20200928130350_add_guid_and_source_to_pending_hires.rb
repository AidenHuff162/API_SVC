class AddGuidAndSourceToPendingHires < ActiveRecord::Migration[5.1]
  def change
    add_column :pending_hires, :guid, :string
    add_column :pending_hires, :source, :string
  end
end
