class CreateSidekiqJobsTable < ActiveRecord::Migration[6.0]
  def change
    create_table :sidekiq_jobs do |t|
      t.string :job_name, null: false
      t.json :job_params, default: nil
      t.datetime :start_time
      t.integer :company_id
      t.timestamps
    end
  end
end
