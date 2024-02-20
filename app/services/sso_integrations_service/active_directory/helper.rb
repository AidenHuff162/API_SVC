class SsoIntegrationsService::ActiveDirectory::Helper
  
  def fetch_integration(company)
    company.integration_instances.find_by(api_identifier: 'adfs_productivity', state: :active)
  end

  def is_integration_valid?(integration)
    integration.present? && integration.access_token.present? && integration.refresh_token.present? && integration.expires_in.present?
  end

  def create_loggings(company, integration_name, state, action, result = {}, api_request = 'No Request')
    LoggingService::IntegrationLogging.new.create(company, integration_name, action, api_request, result, state)
  end

  def fetch_custom_table(company, custom_table_property)
    company.custom_tables.find_by(custom_table_property: custom_table_property)
  end

  def custom_table_based_mapping?(company, custom_table_property)
    company.is_using_custom_table? && fetch_custom_table(company, custom_table_property).present?
  end
end