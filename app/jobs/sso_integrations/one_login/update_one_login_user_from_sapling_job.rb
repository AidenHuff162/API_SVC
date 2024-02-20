class SsoIntegrations::OneLogin::UpdateOneLoginUserFromSaplingJob < ApplicationJob
  queue_as :manage_one_login_integration

  def perform(user_id, field)
    ::SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling.new(user_id).update_one_login_user(field)
  end
end
