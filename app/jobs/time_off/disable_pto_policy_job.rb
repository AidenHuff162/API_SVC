include Sidekiq::Worker
module TimeOff
	class DisablePtoPolicyJob
		sidekiq_options queue_as: :pto_activities

		def perform(policy_id)
			pto_policy = PtoPolicy.find_by(id: policy_id) if policy_id.present?
			pto_policy.assigned_pto_policies.destroy_all if pto_policy.present?
		end

	end
end