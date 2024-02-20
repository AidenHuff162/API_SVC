class AddDeletedAtToIntegrationInstance < ActiveRecord::Migration[5.1]
  def change
    add_column :integration_instances, :deleted_at, :datetime
    add_index :integration_instances, :deleted_at
  end
end
