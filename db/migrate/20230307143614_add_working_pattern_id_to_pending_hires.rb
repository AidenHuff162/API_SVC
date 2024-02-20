class AddWorkingPatternIdToPendingHires < ActiveRecord::Migration[6.0]
  def change
    add_column :pending_hires, :working_pattern_id, :integer
  end
end
