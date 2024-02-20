class HrisIntegrations::Xero::UpdateSaplingUserFromXeroJob
  include Sidekiq::Worker
  sidekiq_options :queue => :receive_employee_from_hr, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by_id(company_id)

    if company.present? && company.is_xero_integrated?
      ::HrisIntegrationsService::Xero::ManageSaplingUserFromXero.new(company).perform
    end
  end
end
