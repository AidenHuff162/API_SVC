class HrisIntegrations::Workday::TerminateUserInWorkdayJob < ApplicationJob
  queue_as :update_employee_to_hr

  def perform(user_id)
    user = User.find_by_id(user_id)
    integration = user.company.get_integration('workday') rescue nil
    user = IntegrationsService::Filters.call(user, integration)
    return if user.blank? || user.super_user

    attrs = { user: user, action: 'terminate' }
    ::HrisIntegrationsService::Workday::ManageSaplingInWorkday.call(attrs)
  end

end
