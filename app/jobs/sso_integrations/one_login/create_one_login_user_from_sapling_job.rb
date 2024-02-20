class SsoIntegrations::OneLogin::CreateOneLoginUserFromSaplingJob
  include Sidekiq::Worker
  sidekiq_options :queue => :add_employee_to_hr, :retry => false, :backtrace => true

  def perform(user_id)
    ::SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling.new(user_id).create_one_login_user
  end
end
