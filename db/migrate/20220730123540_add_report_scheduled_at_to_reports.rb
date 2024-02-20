class AddReportScheduledAtToReports < ActiveRecord::Migration[5.1]
  def change
    add_column :reports, :scheduled_at, :datetime
  end
end
