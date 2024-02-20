module Pto
  class DeductBalances
    def perform company
      company_current_date = company.time.to_date
      company.pto_policies.where(is_enabled: true, unlimited_policy: false).try(:each) do |pto_policy|
        deduct_balance_for_pto_requests(pto_policy, company_current_date)
      end
    end

    private

    def deduct_balance_for_pto_requests pto_policy, current_company_date
      pto_policy.pto_requests.where('DATE(begin_date) = ? and status < ? and balance_deducted = false', current_company_date, PtoRequest.statuses["denied"]).try(:each) do |pto_request|
        begin
          if pto_request.user && pto_request.assigned_pto_policy
            pto_request.balance_hours = pto_request.get_balance_used
            pto_request.update_assigned_policy_balance 
          end
        rescue Exception => e
          LoggingService::GeneralLogging.new.create(pto_request.pto_policy.company, 'Deduct Balance', {result: "Failed to deduct balance for pto_request with id #{pto_request.id}", error: e.message}, 'PTO')           
        end
      end
    end
  end
end
