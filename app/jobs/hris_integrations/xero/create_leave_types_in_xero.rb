class HrisIntegrations::Xero::CreateLeaveTypesInXero
  include Sidekiq::Worker
  sidekiq_options :queue => :pto_activities, :retry => false, :backtrace => true

  def perform(policy_id)
    policy = PtoPolicy.find_by(id: policy_id)

    if policy.present? && policy.xero_leave_type_id.blank? && policy.company.is_xero_integrated?
      ::HrisIntegrationsService::Xero::CreateLeaveTypesInXero.new(policy).create_leave_type
    end
  end
end