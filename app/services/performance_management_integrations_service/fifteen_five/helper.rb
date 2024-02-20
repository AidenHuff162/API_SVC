class PerformanceManagementIntegrationsService::FifteenFive::Helper
  
  def fetch_integration(company)
    company.integration_instances.find_by(api_identifier: 'fifteen_five')
  end

  def is_integration_valid?(integration)
    integration.present? && integration.access_token.present? && integration.subdomain.present?
  end

  def can_integrate_profile?(integration, user)
    return unless integration.present? && integration.filters.present?

    filters = integration.filters
    (apply_to_location?(filters, user) && apply_to_team?(filters, user) && apply_to_employee_type?(filters, user))
  end

  def create_loggings(company, integration_name, state, action, result = {}, api_request = 'No Request')
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

  def log_statistics(action, company, integration)
    if action == 'success'
      integration.update_columns(synced_at: DateTime.now, sync_status: 'succeed') if integration.present?
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(company)
    else
      integration.update_columns(synced_at: DateTime.now, sync_status: 'failed') if integration.present?
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(company)
    end
  end

  private

  def apply_to_location?(filters, user)
    location_ids = filters['location_id']
    location_ids.include?('all') || (location_ids.present? && user.location_id.present? && location_ids.include?(user.location_id))
  end

  def apply_to_team?(filters, user)
    team_ids = filters['team_id']
    team_ids.include?('all') || (team_ids.present? && user.team_id.present? && team_ids.include?(user.team_id))
  end

  def apply_to_employee_type?(filters, user)
    employee_types = filters['employee_type']
    employee_types.include?('all') || (employee_types.present? && user.employee_type_field_option&.option.present? && employee_types.include?(user.employee_type_field_option&.option))
  end
end