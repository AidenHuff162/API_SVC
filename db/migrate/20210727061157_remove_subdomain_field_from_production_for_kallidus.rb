class RemoveSubdomainFieldFromProductionForKallidus < ActiveRecord::Migration[5.1]
  def change
    if Rails.env.production?
      learn_inventory = IntegrationInventory.find_by_api_identifier('kallidus_learn')
      
      if learn_inventory.present?
        field = learn_inventory.integration_configurations.find_by_field_type('subdomain')
        field.destroy! if field.present?
      end
    end
  end
end
