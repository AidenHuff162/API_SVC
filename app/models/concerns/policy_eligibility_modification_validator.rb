class PolicyEligibilityModificationValidator < ActiveModel::Validator

  def validate record
    if record.persisted? && (record.changes_to_save["assign_manually"].present? || record.changes_to_save["for_all_employees"].present?)
      record.errors.add(:base, 'Cannot update eligibility criteira of PTO Policy')
    end
  end

end