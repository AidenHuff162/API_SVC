class HrisIntegrations::Gusto::UpdateSaplingUserFromGustoJob
  include Sidekiq::Worker
  sidekiq_options :queue => :receive_employee_from_hr, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by(id: company_id)
    
    if company.present?
      ::HrisIntegrationsService::Gusto::UpdateGustoProfileInSapling.new(company).update
    end
  end
end