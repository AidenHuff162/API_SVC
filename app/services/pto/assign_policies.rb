module Pto
  class AssignPolicies

    def perform(policy)
      if policy.present?
        if policy.assigned_pto_policies.count > 0
            policy.assigned_pto_policies.destroy_all
        end
        if !policy.for_all_employees && !policy.assign_manually
          filters = policy.filter_policy_by
          users = get_users_by_filters(filters, policy)
        elsif !policy.for_all_employees && policy.assign_manually
          users = user_having_manually_assigend_policies(policy)
        else
          users = policy.company.users
        end
        assigne_policy users, policy
      end
    end
    
    def get_users_by_filters(filters, policy, reassigning_existing_policy = false)
      unless reassigning_existing_policy
        users = policy.company.users
      else
        ids_of_user_enrolled_in_policy = AssignedPtoPolicy.with_deleted.where(pto_policy_id: policy.id).pluck(:user_id)
        users = policy.company.users.where.not(id: ids_of_user_enrolled_in_policy)
      end
      users = users.where(location: filters["location"]) if filters["location"].present? && filters["location"][0] != "all"
      users = users.where(team: filters["teams"]) if filters["teams"].present? && filters["teams"][0] != "all"
      if filters["employee_status"][0] != 'all'
        users = users.joins(:custom_field_values => [custom_field_option: :custom_field]).where("custom_fields.company_id = ? AND custom_fields.field_type = ? AND custom_field_options.id IN (?)", policy.company.id, 13, filters["employee_status"])
      end
      if reassigning_existing_policy
        users
      else
        (users + user_having_manually_assigend_policies(policy)).uniq
      end      
    end

    def assigne_policy(users, policy)      
      user_pto_policies = []
      users.each do |user|
        policy_to_restore = user.assigned_pto_policies.with_deleted.where(pto_policy_id: policy.id).max_by {|obj| obj.id }
        if policy_to_restore.present?
          policy_to_restore.restore(recursive: true)
        else
          user_pto_policies << {pto_policy_id: policy.id, user_id: user.id}
        end
      end
      AssignedPtoPolicy.create(user_pto_policies) if users.present? && !user_pto_policies.empty?
    end

    private

    def user_having_manually_assigend_policies policy
      user_id = []
      recent_deleted_assigned_policies = AssignedPtoPolicy.with_deleted.find_by_sql ['select distinct on ("user_id") * from assigned_pto_policies where pto_policy_id = ? order by user_id, id desc', policy.id]
      recent_deleted_assigned_policies.each do |assigned_policy|
        user_id << assigned_policy.user_id if assigned_policy.manually_assigned
      end
      policy.company.users.where(id: user_id)

    end

  end
end
