class HrisIntegrations::Deputy::UpdateSaplingUserFromDeputyJob
  include Sidekiq::Worker
  sidekiq_options :queue => :receive_employee_from_ld, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by(id: company_id)
    
    if company.present?
      ::HrisIntegrationsService::Deputy::ManageDeputyProfileInSapling.new(company).perform
    end
  end
end
