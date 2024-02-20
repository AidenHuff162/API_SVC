class AddWorkdayWorkerSubtypeInPendingHire < ActiveRecord::Migration[6.0]
  def change
    add_column :pending_hires, :workday_worker_subtype, :string
  end
end
