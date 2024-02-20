class AddSentAtColumnToReport < ActiveRecord::Migration[5.1]
  def change
  	add_column :reports, :sent_at, :datetime
  end
end
