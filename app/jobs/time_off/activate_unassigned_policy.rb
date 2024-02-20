module TimeOff
  class ActivateUnassignedPolicy < ApplicationJob
    queue_as :pto_activities

    def perform
      activate_unassigned_policies
    end

    private

    def activate_unassigned_policies
      return if companies_having_midnight.size == 0
      unassigned_pto_policies = UnassignedPtoPolicy.joins(pto_policy: :company).where("companies.id IN (?)", companies_having_midnight)
      create_assigned_policy unassigned_pto_policies      
    end

    def create_assigned_policy unassigned_pto_policies
      unassigned_pto_policies.each do |unassigned_policy|
        next if unassigned_policy.user.blank? || unassigned_policy.pto_policy.blank?
        if unassigned_policy.effective_date == unassigned_policy.pto_policy.company.time.to_date
          assigned_policy = AssignedPtoPolicy.new
          assigned_policy.balance = unassigned_policy.starting_balance
          assigned_policy.user_id = unassigned_policy.user_id
          assigned_policy.pto_policy_id = unassigned_policy.pto_policy_id
          assigned_policy.manually_assigned = true
          assigned_policy.save
          unassigned_policy.destroy
        end
      end
    end

    def companies_having_midnight
      companies = []
      Company.all.each do |company|
        current_hour = company.time.hour
        if current_hour == 0
          companies << company.id
        end
      end
      companies
    end

  end
end