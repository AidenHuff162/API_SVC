module UserSerializer
  class PermissionsLight < ActiveModel::Serializer
    attributes :id, :manager_id, :location_id, :team_id, :employee_type, :managed_users_count, :current_stage,
    			:managed_users_ids, :indirect_reports_ids, :managed_approval_chain_users_ids, :onboarding_profile_template_id

    def employee_type
      object.employee_type
    end

    def managed_users_count
      object.cached_managed_user_ids.length
    end

    def managed_users_ids
      object.cached_managed_user_ids
    end

    def indirect_reports_ids
    	object.cached_indirect_reports_ids
		end

    def managed_approval_chain_users_ids
      object.managed_approval_chain_users&.pluck(:id)
    end
  end
end
