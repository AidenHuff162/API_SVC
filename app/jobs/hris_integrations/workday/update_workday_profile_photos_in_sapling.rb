class HrisIntegrations::Workday::UpdateWorkdayProfilePhotosInSapling < ApplicationJob
  include HrisIntegrationsService::Workday::Exceptions
  include HrisIntegrationsService::Workday::Logs
  attr_reader :company # for Workday::Logs

  queue_as :receive_employee_from_workday

  def perform(company_id)
    return if (@company = Company.find_by_id(company_id)).blank? || (integration = company.get_integration('workday')).blank?

    begin
      validate_creds_presence!(integration)
      filter_applicable_users = IntegrationsService::Filters.call(company.users.with_workday, integration)
      filter_applicable_users&.each { |user| HrisIntegrationsService::Workday::Update::ProfilePhotosInSapling.call(user) }
      integration.update_column(:synced_at, DateTime.now)
    rescue Exception => @error
      error_log('Unable to syn profile photos in Sapling.')
    end
  end

end
