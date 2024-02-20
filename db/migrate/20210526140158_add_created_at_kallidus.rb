class AddCreatedAtKallidus < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :created_at_kallidus, :datetime
  end
end
