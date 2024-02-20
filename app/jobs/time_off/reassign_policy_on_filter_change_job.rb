module TimeOff
  class ReassignPolicyOnFilterChangeJob
		include Sidekiq::Worker
    sidekiq_options queue: :pto_activities

    def perform policy_id
      Pto::ReassignPolicyOnFilterChange.new(policy_id).perform
    end
  end
end
