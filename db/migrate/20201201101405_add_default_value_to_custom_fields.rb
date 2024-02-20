class AddDefaultValueToCustomFields < ActiveRecord::Migration[5.1]
  def change
     add_column :custom_fields, :default_value, :string
  end
end
