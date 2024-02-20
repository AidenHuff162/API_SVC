class AddWorkingPatternIdToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :working_pattern_id, :integer
  end
end
