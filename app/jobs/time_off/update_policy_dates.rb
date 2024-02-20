module TimeOff
  class UpdatePolicyDates
		include Sidekiq::Worker
    sidekiq_options queue: :pto_activities
    def perform args
      user = User.find_by(id: args["id"])
      user.assigned_pto_policies.where(is_balance_calculated_before: false).try(:each) do |assigned_pto_policy|
        assigned_pto_policy.initialize_accrual_start_date_and_happening_date
      end if user
    end
  end
end
