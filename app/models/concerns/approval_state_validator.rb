class ApprovalStateValidator < ActiveModel::Validator
  def validate record
    invalid_for_approval(record) if record.approved? 
    invalid_for_manager_and_coworker(record) if !record.approved?
  end

  def invalid_for_approval record
    record.ctus_approval_chains.try(:each) do |approval|
      if !approval.approved? && !approval.skipped?
        record.errors.add(:request_state, I18n.t('errors.invalid_state').to_s)
      end
    end 
  end

  def invalid_for_manager_and_coworker record
    approval_chains = record.get_approval_chains
    approval_chains.try(:each) do |approval_chain|
      if approval_chain.manager? && 
        !record.user.manager_level(approval_chain.approval_ids[0])
        record.errors.add(:approval_chains, I18n.t('errors.no_manager', 
          level: approval_chain.approval_ids[0]).to_s)
      elsif approval_chain.coworker? && 
        !record.user.get_custom_coworker(approval_chain.approval_ids[0])
        record.errors.add(:approval_chains, I18n.t('errors.no_coworker').to_s)
      end
    end
  end
end