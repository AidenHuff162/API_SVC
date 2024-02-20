module TimeOff
  class AutoCompletePtoRequestJob < ApplicationJob
    queue_as :pto_calculations
    def perform
      PtoPolicy.where(manager_approval: true, is_enabled: true).find_each do |policy|
        time_limit = policy.days_to_wait_until_auto_actionable.days.ago
        policy.pto_requests.where(partner_pto_request_id: nil).where('status = ? and submission_date < ? ', PtoRequest.statuses['pending'], time_limit).each do |pto_request|
          begin
            if policy.auto_approval
              pto_request.update!(status: 1, request_auto_updated: true, status_changed_by: "Auto Approved")
              pto_request.create_auto_approved_activity(pto_request.user_id)
            else
              pto_request.update!(status: 2, request_auto_updated: true, status_changed_by: "Auto Denied")
              pto_request.create_auto_deny_activity(pto_request.user_id)
            end
          rescue Exception=>e
            LoggingService::GeneralLogging.new.create(policy.company, 'Auto Complete PTO', {result: "Failed to auto complete pto_request with id #{pto_request.id}", error: e.message}, 'PTO')           
          end
        end
      end
    end
  end
end
