class HrisIntegrations::AdpWorkforceNow::UpdateSaplingIntegrationOptionMappingsFromAdpJob < ApplicationJob
  queue_as :update_adp_integration_mappings
  
  def perform(integration_id, all_settings = true)
  	integration = IntegrationInstance.find_by_id(integration_id)

  	if integration.present?
  		::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingCustomFieldOptionsFromAdp.new(integration).sync
  		::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingGroupOptionsFromAdp.new(integration).sync
	  end
  end
end
