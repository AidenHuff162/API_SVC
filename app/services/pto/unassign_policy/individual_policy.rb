module PTO
	module UnassignPolicy
		class IndividualPolicy
			attr_reader :policy_id, :user_id

			def initialize policy_id, user_id
				@policy_id = policy_id
				@user_id = user_id
				@response = {}
			end

			def perform
				fetch_and_destroy_assigned_policy
				@response
			end

			private

			def fetch_and_destroy_assigned_policy
				assigned_policy = AssignedPtoPolicy.where(pto_policy_id: @policy_id, user_id: @user_id).order('id desc').first
        assigned_policy.manually_assigned = false
				assigned_policy.balance = 0
				if assigned_policy.save and assigned_policy.destroy!
					@response[:status] = 200
				end
			end

		end
	end
end