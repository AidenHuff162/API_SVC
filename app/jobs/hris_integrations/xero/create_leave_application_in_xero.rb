class HrisIntegrations::Xero::CreateLeaveApplicationInXero
  include Sidekiq::Worker
  sidekiq_options :queue => :pto_activities, :retry => 0, :backtrace => true

  def perform(pto_request_id)
    pto_request = PtoRequest.find_by(id: pto_request_id)
    
    if pto_request.present? && pto_request.user.xero_id.present? && pto_request.pto_policy.xero_leave_type_id.present? && pto_request.pto_policy.company.is_xero_integrated?
      ::HrisIntegrationsService::Xero::CreateLeaveApplicationsInXero.new(pto_request).create_leave_application
    end
  end
end