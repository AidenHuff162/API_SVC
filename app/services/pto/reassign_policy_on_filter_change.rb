module Pto
  class ReassignPolicyOnFilterChange

    def initialize policy_id
      @policy = PtoPolicy.find(policy_id)
    end

    def perform
      unless policy_filters_are_set_to_all
        remove_assigned_policies_not_having_current_filters
        restore_previously_assigned_policies_having_current_filters
        assigned_policy_to_new_users
      else
        restore_previously_assigned_policies_having_current_filters
        assigned_policy_to_new_users
      end
    end

    private

    def remove_assigned_policies_not_having_current_filters
      @policy.assigned_pto_policies.includes(:user).auto_assigned_policies.each do |assigned_policy|
        assigned_policy.destroy unless PTO::SharedMethods::UserPolicyFilterMatcher.assigned_policys_user_has_pto_policy_filter?(@policy, assigned_policy)
      end
    end

    def restore_previously_assigned_policies_having_current_filters
      assigned_pto_policies  = AssignedPtoPolicy.find_by_sql ['select distinct on ("user_id") * from assigned_pto_policies where( pto_policy_id = ? and deleted_at is not null) order by "user_id", created_at DESC, id DESC', @policy.id]
      ActiveRecord::Associations::Preloader.new.preload(assigned_pto_policies, :user)
      assigned_pto_policies.each do |assigned_policy|
        assigned_policy.restore(recursive: true) if assigned_policy.user.present? && PTO::SharedMethods::UserPolicyFilterMatcher.assigned_policys_user_has_pto_policy_filter?(@policy, assigned_policy)
      end
    end

    def assigned_policy_to_new_users
      users = Pto::AssignPolicies.new.get_users_by_filters(@policy.filter_policy_by, @policy, true)
      Pto::AssignPolicies.new.assigne_policy(users, @policy)
    end

    def policy_filters_are_set_to_all
      (@policy.filter_policy_by["teams"] == ['all'] && @policy.filter_policy_by['location'] == ['all'] && @policy.filter_policy_by['employee_status'] == ['all'])
    end

  end
end
