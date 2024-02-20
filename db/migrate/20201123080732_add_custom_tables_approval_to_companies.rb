class AddCustomTablesApprovalToCompanies < ActiveRecord::Migration[5.1]
  def change
    add_column :companies, :enable_custom_table_approval_engine, :boolean, default: false
  end
end
