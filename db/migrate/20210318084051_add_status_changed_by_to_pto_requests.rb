class AddStatusChangedByToPtoRequests < ActiveRecord::Migration[5.1]
  def change
    add_column :pto_requests, :status_changed_by, :string
  end
end
