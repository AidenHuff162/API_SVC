class HrisIntegrationsService::Paychex::Helper
  
  def fetch_integration(company)
    company.integration_instances.find_by(api_identifier: 'paychex')
  end

  def is_integration_valid?(integration)
    integration.present? && integration.access_token.present? && integration.subdomain.present? && integration.company_code.present?
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
  # :nocov:
  def notify_slack(message)
    ::IntegrationErrors::SendIntegrationErrorNotificationToSlackJob.perform_now(message,
      IntegrationErrorSlackWebhook.integration_types.key(IntegrationErrorSlackWebhook.integration_types[:human_resource_information_system]))
  end
  # :nocov:
  def log_statistics(action, company)
    if action == 'success'
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(company)
    else
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(company)
    end
  end

  def saved_integration_credentials(response, integration)    
    response_data = JSON.parse(response.read_body)

    integration.access_token(response_data['access_token'])
    integration.expires_in(Time.now.utc + response_data['expires_in'])
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