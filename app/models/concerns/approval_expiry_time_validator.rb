class ApprovalExpiryTimeValidator < ActiveModel::Validator
  def validate record
    if record.is_approval_required.present?
      invalid_expiry_time(record) if record.approval_expiry_time.blank? || record.approval_expiry_time.zero?
    end
  end

  def invalid_expiry_time record
    record.errors.add(:approval_expiry_time, I18n.t('errors.invalid_expiry_time').to_s)
  end
end