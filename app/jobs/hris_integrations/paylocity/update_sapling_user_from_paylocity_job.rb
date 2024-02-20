class HrisIntegrations::Paylocity::UpdateSaplingUserFromPaylocityJob
  include Sidekiq::Worker
  sidekiq_options :queue => :receive_employee_from_paylocity, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by_id(company_id)

    if company.present?
      ::HrisIntegrationsService::Paylocity::ManagePaylocityProfileInSapling.new(company).perform
    end
  end
end