class AddIsAuthorizedToIntegrationInstances < ActiveRecord::Migration[5.1]
  def change
     add_column :integration_instances, :is_authorized, :boolean, default: false
  end
end
