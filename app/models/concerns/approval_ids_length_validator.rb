class ApprovalIdsLengthValidator < ActiveModel::Validator
	def validate record
    invalid_for_person(record) if record.person?
    invalid_for_manager(record) if record.manager? || record.requestor_manager?
    invalid_for_permission(record) if record.permission?
    invalid_for_coworker(record) if record.coworker?
  end

	def invalid_for_person record
		if (record.approval_ids&.length != 1 ||
      record.approval_ids&.length == 1 &&
      record.approval_ids[0] == '')
      record.errors.add(:approval_ids, I18n.t('errors.invalid_for_person').to_s)
    end
	end

	def invalid_for_manager record
    if (record.approvable_type == 'CustomTable' &&
      record.approval_ids&.length != 1 ||
      (record.approval_ids&.length == 1 && record.approval_ids[0] == ''))
      record.errors.add(:approval_ids, I18n.t('errors.invalid_for_manager').to_s)
    elsif (record.approvable_type == 'PtoPolicy' &&
      record.approval_ids&.length != 0 && !record.approval_ids&.length.nil?)
      record.errors.add(:approval_ids, I18n.t('errors.invalid_for_manager').to_s)
    end
	end

  def invalid_for_permission record
    if record.approval_ids&.length == 0
      record.errors.add(:approval_ids, I18n.t('errors.invalid_for_permission').to_s)
    end
  end

  def invalid_for_coworker record
    if (record.approval_ids&.length != 1 &&
      record.approval_ids&.length != 1 &&
      record.approval_ids[0] == '')
      record.errors.add(:approval_ids, I18n.t('errors.invalid_for_coworker').to_s)
    end
  end
end
