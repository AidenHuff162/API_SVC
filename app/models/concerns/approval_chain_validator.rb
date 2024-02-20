class ApprovalChainValidator < ActiveModel::Validator
  def validate record
    if record.is_approval_required.present?
      invalid_approval_chain(record)
    end
  end

  def invalid_approval_chain record
    if record.approval_chains.empty?
      record.errors.add(:approval_chain, I18n.t('errors.invalid_approval_chain').to_s)
    end
  end
end