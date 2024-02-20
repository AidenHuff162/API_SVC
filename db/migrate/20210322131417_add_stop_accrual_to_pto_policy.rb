class AddStopAccrualToPtoPolicy < ActiveRecord::Migration[5.1]
  def change
    add_column :pto_policies, :has_stop_accrual_date, :boolean, default: false
    add_column :pto_policies, :stop_accrual_date, :float, default: 0.0
  end
end
