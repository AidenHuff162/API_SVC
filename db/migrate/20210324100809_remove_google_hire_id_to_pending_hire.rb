class RemoveGoogleHireIdToPendingHire < ActiveRecord::Migration[5.1]
  def change
    remove_column :pending_hires, :google_hire_id, :string
  end
end
