class HrisIntegrations::Xero::CreateCompanyLeaveTypesInXero
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by(id: company_id)

    return if company.blank? || !company.is_xero_integrated?

    company.pto_policies.find_each do |policy|
      ::HrisIntegrations::Xero::CreateLeaveTypesInXero.perform_async(policy.id) if policy.xero_leave_type_id.blank?
    end
  end
end