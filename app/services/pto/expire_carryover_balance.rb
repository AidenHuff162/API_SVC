module Pto
  class ExpireCarryoverBalance 
    def perform(company_id)
      @company_date = Company.find(company_id).time.to_date - 1.day
      policies = AssignedPtoPolicy.joins(:pto_policy).where("pto_policies.expire_unused_carryover_balance = true AND extract(day  from pto_policies.carryover_amount_expiry_date) = ? AND extract(month  from pto_policies.carryover_amount_expiry_date) = ? AND carryover_balance > 0 AND pto_policies.company_id = ? AND pto_policies.unlimited_policy = false AND pto_policies.is_enabled = true" , @company_date.day, @company_date.month, company_id)
      policies.try(:each) do |assigned_policy|
        begin 
          create_log assigned_policy
          assigned_policy.carryover_balance = 0
          assigned_policy.initial_carryover_balance = nil
          assigned_policy.save!
        rescue Exception=>e
          LoggingService::GeneralLogging.new.create(Company.find_by(id: company_id), 'Expire Carryover', {result: "Failed to Expire balance for assigned_pto_policy with id #{assigned_policy.id}", error: e.message}, 'PTO')           
        end
      end
    end

    def create_log assigned_policy
      assigned_policy.pto_balance_audit_logs.create(balance_used: assigned_policy.carryover_balance, balance_added: 0,  balance: assigned_policy.balance, description: "Carryover Expired", balance_updated_at: @company_date, user_id: assigned_policy.user_id)
    end
  end
end
