class AddInitialCarryoverBalanceToAssignedPtoPolicy < ActiveRecord::Migration[5.1]
  def change
    add_column :assigned_pto_policies, :initial_carryover_balance, :float, default: nil
  end
end
