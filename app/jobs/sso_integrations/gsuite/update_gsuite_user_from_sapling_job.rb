class SsoIntegrations::Gsuite::UpdateGsuiteUserFromSaplingJob < ApplicationJob
  queue_as :manage_one_login_integration

  def perform(user_id, update_ou=false)
  	::Gsuite::ManageAccount.new.update_gsuite_account(user_id, update_ou) if user_id.present?
  end
end
