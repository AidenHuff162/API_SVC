class AddDeletedAtColoumnInHoliday < ActiveRecord::Migration[6.0]
  def change
    add_column :holidays, :deleted_at, :datetime, default: nil
  end
end
