module IntegrationManagement
  extend ActiveSupport::Concern

  def manage_profile_setup_on_integration_change(company)
    integration = IntegrationsService::IntegrationChangeManagement.new(company)
    integration.manage_profile_setup_on_integration_change
  end

  def manage_phone_format_conversion(company)
    integration = IntegrationsService::IntegrationChangeManagement.new(company)
    integration.manage_phone_format_conversion
  end
end
