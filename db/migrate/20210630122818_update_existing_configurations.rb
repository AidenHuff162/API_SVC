class UpdateExistingConfigurations < ActiveRecord::Migration[5.1]
  def change
    gusto = IntegrationInventory.find_by(api_identifier: 'gusto')
    return unless gusto.present?
    company_code = gusto.integration_configurations.find_by(field_name: 'Company Code')
    return unless company_code.present?
    company_code.update(field_type: 'options')
  end
end
