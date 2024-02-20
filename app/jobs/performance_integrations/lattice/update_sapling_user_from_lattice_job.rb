class PerformanceIntegrations::Lattice::UpdateSaplingUserFromLatticeJob
  include Sidekiq::Worker
  sidekiq_options :queue => :receive_employee_from_pm, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by_id(company_id)

    if company.present?
      ::PerformanceManagementIntegrationsService::Lattice::ManageLatticeProfileInSapling.new(company).perform
    end
  end
end