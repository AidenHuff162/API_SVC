class ChangeOptionsColumnsType < ActiveRecord::Migration[5.1]
  def change
    remove_column :integration_configurations, :dropdown_options, :string
    add_column :integration_configurations, :dropdown_options, :jsonb
  end
end
