module PTO
  module SharedMethods
    class UserPolicyFilterMatcher

      def self.assigned_policys_user_has_pto_policy_filter? policy, assigned_policy
        return true unless policy_not_for_all_employees?(policy)
        return false if assigned_policy.user.blank?
        filters = policy.reload.filter_policy_by
        employee_status = assigned_policy.user.get_employment_status
        if filters["teams"] == ['all'] && filters['location'] == ['all'] && filters['employee_status'] != ['all']
          filters['employee_status'].include? employee_status
        elsif filters["teams"] != ['all'] && filters['location'] == ['all'] && filters['employee_status'] == ['all']
          filters['teams'].include? assigned_policy.user.team_id
        elsif filters["teams"] == ['all'] && filters['location'] != ['all'] && filters['employee_status'] == ['all']
          filters['location'].include? assigned_policy.user.location_id
        elsif filters["teams"] != ['all'] && filters['location'] != ['all'] && filters['employee_status'] == ['all']
          filters['teams'].include? assigned_policy.user.team_id and filters['location'].include? assigned_policy.user.location_id
        elsif filters["teams"] == ['all'] && filters['location'] != ['all'] && filters['employee_status'] != ['all']
          filters['employee_status'].include? employee_status and filters['location'].include? assigned_policy.user.location_id
        elsif filters["teams"] != ['all'] && filters['location'] == ['all'] && filters['employee_status'] != ['all']
          filters['employee_status'].include? employee_status and filters['teams'].include? assigned_policy.user.team_id
        elsif filters["teams"] != ['all'] && filters['location'] != ['all'] && filters['employee_status'] != ['all']
          filters['employee_status'].include? employee_status and filters['location'].include? assigned_policy.user.location_id and filters['teams'].include? assigned_policy.user.team_id
        end
      end

      def self.policy_not_for_all_employees?(policy)
        !policy.for_all_employees and (policy.filter_policy_by["teams"] != ['all'] || policy.filter_policy_by['location'] != ['all'] || policy.filter_policy_by['employee_status'] != ['all'])
      end

    end
  end
end
