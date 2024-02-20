class AddJobIdInReports < ActiveRecord::Migration[5.1]
  def change
    add_column :reports, :job_id, :string
  end
end
