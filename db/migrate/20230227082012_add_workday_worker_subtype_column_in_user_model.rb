class AddWorkdayWorkerSubtypeColumnInUserModel < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :workday_worker_subtype, :string
  end
end
