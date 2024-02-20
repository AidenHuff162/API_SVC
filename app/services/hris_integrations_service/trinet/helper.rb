class HrisIntegrationsService::Trinet::Helper
  
  def fetch_integration(company, user)
    company.integration_instances.where(api_identifier: 'trinet').find_each do |instance|
      return instance if can_integrate_profile?(instance, user)
    end
  end

  def is_integration_valid?(integration)
    integration.present? && integration.access_token.present?
  end

  def can_integrate_profile?(integration, user)
    return unless integration.present? && integration.filters.present?
      
    filter = integration.filters
    (apply_to_location?(filter, user) && apply_to_team?(filter, user) && apply_to_employee_type?(filter, user))
  end

  def create_loggings(company, integration, integration_name, state, action, result = {}, api_request = 'No Request')
    [200, 201, 204].include?(state) ? integration.succeed! : integration.failed!
    
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
    ::IntegrationErrors::SendIntegrationErrorNotificationToSlackJob.perform_now(message,
      IntegrationErrorSlackWebhook.integration_types.key(IntegrationErrorSlackWebhook.integration_types[:human_resource_information_system]))
  end

  def log_statistics(action, company)
    if action == 'success'
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(company)
    else
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(company)
    end
  end

  def saved_integration_credentials(response, integration)    
    response_data = JSON.parse(response.body)
    
    integration.access_token(response_data['access_token'])
    integration.expires_in(Time.now.utc + response_data['expires_in'].to_i)
    integration.reload
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