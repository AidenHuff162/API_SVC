class HrisIntegrationsService::Bamboo::Initializer
  attr_reader :company, :bamboo_api

  def initialize(company)
    @company = company
    @bamboo_api = initialize_bamboo_api
  end

  def bamboo_api_initialized?
    !bamboo_api.blank? && !bamboo_api.subdomain.blank? && !bamboo_api.api_key.blank?
  end

  private

  def initialize_bamboo_api
    !company.blank? && company.integration_types.include?("bamboo_hr") ? company.integration_instances.find_by(api_identifier: 'bamboo_hr', state: :active) : nil
  end

  def log(action, request, response, status)
    LoggingService::IntegrationLogging.new.create(@company, 'BambooHR', action, request, response, status)
  end
end
