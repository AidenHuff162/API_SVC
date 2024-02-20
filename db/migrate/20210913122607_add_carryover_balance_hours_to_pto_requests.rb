class AddCarryoverBalanceHoursToPtoRequests < ActiveRecord::Migration[5.1]
  def change
    add_column :pto_requests, :carryover_balance_hours, :float, default: 0.0
  end
end
