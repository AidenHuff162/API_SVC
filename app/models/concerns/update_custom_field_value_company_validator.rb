class UpdateCustomFieldValueCompanyValidator < ActiveModel::Validator

  def validate record
    if User.current.present?
      if record.sub_custom_field.present?
        unless record.sub_custom_field.custom_field.company_id == User.current.company_id
          record.errors.add(:base, 'Custom field belongs to different company')
        end
      else
        unless record.custom_field.company_id == User.current.company_id
          record.errors.add(:base, 'Custom field belongs to different company')
        end
      end
    end
  end

end
