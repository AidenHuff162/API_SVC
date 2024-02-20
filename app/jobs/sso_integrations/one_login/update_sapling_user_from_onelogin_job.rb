class SsoIntegrations::OneLogin::UpdateSaplingUserFromOneloginJob
  include Sidekiq::Worker
  sidekiq_options :queue => :receive_employee_from_sso, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by_id(company_id)

    if company.present? && company.authentication_type == 'one_login'
      ::SsoIntegrationsService::OneLogin::ManageOneLoginProfileInSapling.new(company).perform
    end
  end
end
