class AddTrialDateToBillings < ActiveRecord::Migration[5.1]
  def change
    add_column :billings, :trial_start_date, :datetime
    add_column :billings, :trial_end_date, :datetime
  end
end
