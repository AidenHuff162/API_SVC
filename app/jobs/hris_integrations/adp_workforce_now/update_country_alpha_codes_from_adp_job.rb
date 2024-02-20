class HrisIntegrations::AdpWorkforceNow::UpdateCountryAlphaCodesFromAdpJob < ApplicationJob
  queue_as :update_adp_integration_mappings
  
  def perform(integration_id)
    integration = IntegrationInstance.find_by_id(integration_id)

    if integration.present?
      ::HrisIntegrationsService::AdpWorkforceNowU::UpdateCountryAlphaCodesFromAdp.new(integration).sync
    end
  end
end