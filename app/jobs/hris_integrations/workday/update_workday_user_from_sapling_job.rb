class HrisIntegrations::Workday::UpdateWorkdayUserFromSaplingJob < ApplicationJob
  queue_as :update_employee_to_hr

  def perform(user_id, field_names, doc_file_hash={})
    return unless (user = User.find_by_id(user_id)).present?

    user = IntegrationsService::Filters.call(user, user.company.get_integration('workday'))
    return if user.blank? || user.super_user

    attrs = { user: user, action: 'update', field_names: field_names, doc_file_hash: doc_file_hash.with_indifferent_access }
    ::HrisIntegrationsService::Workday::ManageSaplingInWorkday.call(attrs)
  end

end
