class HrisIntegrations::Namely::UpdateSaplingUserFromNamelyJob
  include Sidekiq::Worker
  sidekiq_options :queue => :receive_employee_from_hr, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by_id(company_id)
    if company.present?
      ::HrisIntegrationsService::Namely::ManageNamelyProfileInSapling.new(company).perform
    end
  end
end
