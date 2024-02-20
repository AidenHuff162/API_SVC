class AddMigrationStatusToCompany < ActiveRecord::Migration[6.0]
  def change
    add_column :companies, :migration_status, :integer, default: nil
  end
end
