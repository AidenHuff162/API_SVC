class AddErrorCodeAndErrorNameAndErrorCategoryToHellosignCalls < ActiveRecord::Migration[5.1]
  def change
    add_column :hellosign_calls, :error_code, :string
    add_column :hellosign_calls, :error_name, :string
    add_column :hellosign_calls, :error_category, :integer
  end
end
