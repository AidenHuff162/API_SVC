class AddLessonlyIdInUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :lessonly_id, :string
  end
end
