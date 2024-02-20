class DropTableTerminationEmails < ActiveRecord::Migration[5.1]
  def change
    drop_table :termination_emails
  end
end
