module PTO
	module AssignPolicy
		class IndividualPolicy

			attr_reader :effective_date, :policy_id, :user_id, :starting_balance, :company_id

			def initialize effective_date, policy_id, user_id, starting_balance, company_id
				@effective_date = effective_date
				@policy_id = policy_id
				@user_id = user_id
				@starting_balance = starting_balance
				@company_id = company_id
				@response = nil
			end

			def perform
				remove_existing_unassigned_pto_policy
				if assign_now?
					assign_immediately
				else
					assign_later
				end
				@response
			end

			private

			def remove_existing_unassigned_pto_policy
				old_unassigned_policy = UnassignedPtoPolicy.where(user_id: @user_id, pto_policy_id: @policy_id).first
				old_unassigned_policy.destroy if old_unassigned_policy.present?
			end

			def assign_immediately
				assigned_policy = AssignedPtoPolicy.new
				assigned_policy.pto_policy_id = @policy_id
				assigned_policy.user_id = @user_id
				assigned_policy.balance = get_starting_balance
        assigned_policy.manually_assigned = true
				if assigned_policy.save
					@response = assigned_policy
				end
			end

			def assign_later
				unassigned_policy = UnassignedPtoPolicy.new
				unassigned_policy.pto_policy_id = @policy_id
				unassigned_policy.user_id = @user_id
				unassigned_policy.effective_date = @effective_date
				unassigned_policy.starting_balance = get_starting_balance
				if unassigned_policy.save
					@response = unassigned_policy
				end
			end

			def set_success_response assigned_immediately
				if assigned_immediately
					@response[:success_message] = I18n.t('onboard.home.time_off.assign_new_policy.assigned_successfully_immediately')
				else
					@response[:success_message] = I18n.t('onboard.home.time_off.assign_new_policy.assigned_successfully_later')
				end
			end

			def assign_now?
				company = Company.find(@company_id)
				company.time.to_date >= Date.parse(@effective_date)
			end

      def get_starting_balance
        policy = PtoPolicy.find(@policy_id)
        if policy.tracking_unit == 'daily_policy'
          @starting_balance = @starting_balance * policy.working_hours
        else
          @starting_balance
        end
      end

		end
	end
end