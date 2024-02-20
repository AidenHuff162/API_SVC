class HrisIntegrationsService::Deputy::Helper
  
  def fetch_integration(company)
    company.integration_instances.find_by(api_identifier: 'deputy')
  end

  def is_integration_valid?(integration)
    integration.present? && integration.access_token.present? && integration.refresh_token.present? && integration.subdomain.present? && integration.expires_in.present?
  end

  def can_integrate_profile?(integration, user)
    return unless integration.present? && integration.filters.present?
      
    filter = integration.filters
    (apply_to_location?(filter, user) && apply_to_team?(filter, user) && apply_to_employee_type?(filter, user))
  end

  def create_loggings(company, integration_name, state, action, result = {}, api_request = 'No Request')
    [200, 201, 204].include?(state) ? fetch_integration(company).succeed! : fetch_integration(company).failed!

    LoggingService::IntegrationLogging.new.create(
      company,
      integration_name,
      action,
      api_request,
      result,
      state.to_s
    )
  end

  def notify_slack(message)
    # ::IntegrationErrors::SendIntegrationErrorNotificationToSlackJob.perform_now(message,
      # IntegrationErrorSlackWebhook.integration_types.key(IntegrationErrorSlackWebhook.integration_types[:human_resource_information_system]))
  end

  def get_mapped_location_id(user)
    return unless user.location.try(:name).present?

    deputy_companies = ::HrisIntegrationsService::Deputy::ManageDeputyCompanies.new.create_deputy_company(fetch_integration(user.company))
    return unless deputy_companies.present?

    deputy_companies.select { |deputy_company| deputy_company['CompanyName'].downcase.strip == user.location.name.downcase.strip }[0]['Id'] rescue nil
  end

  def get_mapped_gender_code(gender)
    return 0 unless gender.present?
    
    return (gender.downcase.strip == 'male') ? 1 : 2
  end

  def get_mapped_home_address(address)
    return unless address.present?

    {
      strStreet: "#{address[:line1].to_s} #{address[:line2].to_s}".strip,
      strState: address[:state],
      strCity: address[:city],
      strPostCode: address[:zip],
      strCountryCode: Country.find_by(name: address[:country])&.key.to_s
    }
  end
  
  def fetch_custom_table(company, custom_table_property)
    company.custom_tables.find_by(custom_table_property: custom_table_property)
  end

  def custom_table_based_mapping?(company, custom_table_property)
    company.is_using_custom_table? && fetch_custom_table(company, custom_table_property).present?
  end

  def get_mapped_currency_value(value)
    return unless value.present?

    if value.class == Hash
      return (value['currency_value'] || 0) rescue 0
    else
      return value
    end
  end

  def apply_to_location?(meta, user)
    location_ids = meta['location_id']
    location_ids.include?('all') || (location_ids.present? && user.location_id.present? && location_ids.include?(user.location_id))
  end

  def apply_to_team?(meta, user)
    team_ids = meta['team_id']
    team_ids.include?('all') || (team_ids.present? && user.team_id.present? && team_ids.include?(user.team_id))
  end

  def apply_to_employee_type?(meta, user)
    employee_types = meta['employee_type']
    employee_types.include?('all') || (employee_types.present? && user.employee_type_field_option&.option.present? && employee_types.include?(user.employee_type_field_option&.option))
  end
end