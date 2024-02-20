class HrisIntegrations::AdpWorkforceNow::UpdateCompanyCodesFromAdpJob < ApplicationJob
  queue_as :update_adp_integration_mappings
  
  def perform(integration_id)
    integration = IntegrationInstance.find_by_id(integration_id)

    if integration.present? && integration.enable_company_code.present?
      ::HrisIntegrationsService::AdpWorkforceNowU::UpdateCompanyCodesFromAdp.new(integration).sync
    end
  end
end