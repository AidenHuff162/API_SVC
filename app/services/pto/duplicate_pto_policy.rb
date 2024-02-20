module Pto
  class DuplicatePtoPolicy
    attr_reader :company, :current_policy
    def initialize(policy_id, company)
      @company = company
      @current_policy = @company.pto_policies.find_by_id(policy_id)
    end

    def perform
      new_policy = current_policy.dup
      new_policy.name = initialize_name
      update_policies_position

      new_policy.position = current_policy.position + 1
      new_policy.is_enabled = false
      new_policy.save!

      duplicate_policy_approval_chains(new_policy)
      duplicate_policy_tenureships(new_policy)
      new_policy
    end

    def initialize_name
      pattern = "%#{current_policy.name.to_s[0, current_policy.name.length]}%"
      duplicate_name = current_policy.name.insert(0, 'Copy of ')
      duplicate_name = duplicate_name + " (#{company.pto_policies.where("name LIKE ?",pattern).count})"
    end

    def update_policies_position
      pto_policies = company.pto_policies.where("position > ?", current_policy.position)
      if pto_policies.present?
        pto_policies.update_all("position= position + 1")
      end
    end

    def duplicate_policy_approval_chains(new_policy)
      current_policy.approval_chains.each do |approval_chain|
        new_approval_chain = approval_chain.dup
        new_approval_chain.approvable_id = new_policy.id
        new_approval_chain.save
      end
    end

    def duplicate_policy_tenureships(new_policy)
      current_policy.policy_tenureships.each do |tenureship|
        new_tenureship = tenureship.dup
        new_tenureship.pto_policy_id = new_policy.id
        new_tenureship.save
      end
    end
  end
end
