class HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob < ApplicationJob
  queue_as :update_employee_to_hr

  def perform(user, field_name)
    return if user.super_user
    ::HrisIntegrationsService::Bamboo::UpdateBambooFromSapling.new(user, false).update(field_name)
  end
end
