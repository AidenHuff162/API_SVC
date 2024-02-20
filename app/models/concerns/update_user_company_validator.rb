class UpdateUserCompanyValidator < ActiveModel::Validator

  def validate record
    if User.current.present?
      unless record.company_id == User.current.company_id
        record.errors.add(:base, 'Current user belongs to different company')
      end
    end
  end

end
