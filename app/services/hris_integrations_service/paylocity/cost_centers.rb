class HrisIntegrationsService::Paylocity::CostCenters 

  attr_reader :integration, :sapling_keys, :field_name, :company

  delegate :fetch_integration, :create_loggings, :log_statistics, to: :helper_service

  def initialize(field_name, company)
    @field_name = field_name
    @company = company
    @integration = fetch_integration(@company).take
    @sapling_keys = Integration.paylocity
  end

  def fetch
    begin
      options = configuration.get_basic_options(sapling_keys.client_id, sapling_keys.secret_token)
      resp = event_service.fetch_codes(integration.company_code, options, field_name)
      if resp.ok?
        cost_options = JSON.parse(resp.body)
        configuration = integration.integration_inventory.integration_configurations.find_or_create_by(field_name: field_name, category: 'credentials', field_type: 'dropdown', is_visible: false)
        option_credential = integration.integration_credentials.find_or_create_by(name: configuration.field_name, integration_configuration_id: configuration.id)
        data = {}
        cost_options.each do |option|
          data.merge!("#{option['description'].downcase.parameterize.underscore}": {name: option['description'], option: option['code']})
        end      
        option_credential.update(dropdown_options: data)
      else
        create_loggings(company, 'Fetching Cost Center', 500, field_name, resp)
        return nil
      end
    rescue Exception => e
      create_loggings(company, 'Fetching Cost Center', 500, field_name, e.message)
      log_statistics('failed', company)
      return nil
    end

  end

  private

  def configuration 
    HrisIntegrationsService::Paylocity::Configuration.new
  end

  def event_service
    HrisIntegrationsService::Paylocity::Eventsv2.new 
  end

  def helper_service
    ::HrisIntegrationsService::Paylocity::Helper.new
  end
end