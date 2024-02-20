class AddTemporaryEmailToUsers < ActiveRecord::Migration[5.1]
  def change
    #need to remove this migration once statestitle data is moved.
    add_column :users, :temporary_email, :string
  end
end
