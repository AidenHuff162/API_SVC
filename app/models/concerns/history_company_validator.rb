class HistoryCompanyValidator < ActiveModel::Validator

  def validate record
    if record.integration.present? || record.integration_instance.present?
      if record.custom_field.present?
        validate_custom_field(record, (record.integration || record.integration_instance))
      elsif record.field_auditable.class.name == 'Profile'
        validate_profie_field(record, (record.integration || record.integration_instance))
      else
        validate_user_field(record, (record.integration || record.integration_instance))
      end
    else
      if record.custom_field.present?
        validate_custom_field(record)
      elsif record.field_auditable.class.name == 'Profile'
        validate_profie_field(record)
      else
        validate_user_field(record)
      end
    end
  end

  private

  def validate_custom_field record, integration = nil
    if integration.present?
      validate_custom_field_company_and_integration(record)
    else
      if record.custom_field.company_id != record.field_changer.company_id || record.field_auditable.company_id != record.field_changer.company_id
        record.errors.add(:base, "Field history belong to the same company as custom field")
      end
    end
  end

  def validate_profie_field record, integration = nil
    if integration.present?
      validate_profile_company_and_integration(record)
    else
      unless record.field_auditable.user.company_id == record.field_changer.company_id
        record.errors.add(:base, "Field history belong to the same company as permanent field")
      end
    end
  end

  def validate_user_field record, integration = nil
    if integration.present?
      validate_user_company_and_integration(record)
    else
      unless record.field_auditable.company_id == record.field_changer.company_id
        record.errors.add(:base, "Field history belong to the same company as permanent field")
      end
    end
  end

  def validate_user_company_and_integration record
    company_id = get_record_company_id(record)
    unless record.field_auditable.company_id == company_id
      record.errors.add(:base, "Field history belong to the same company as permanent field")
    end
  end

  def validate_profile_company_and_integration record
    company_id = get_record_company_id(record)
    unless record.field_auditable.user.company_id == company_id
      record.errors.add(:base, "Field history belong to the same company as permanent field")
    end
  end

  def validate_custom_field_company_and_integration record
    company_id = get_record_company_id(record)
    if record.field_auditable.company_id != company_id || record.custom_field.company_id != company_id
      record.errors.add(:base, "Field history should belong to the same company as custom field")
    end
  end

  def get_record_company_id record
    company_id = nil
    if record.integration.present?
      company_id = record.integration.company_id
    elsif record.integration_instance.present?
      company_id = record.integration_instance.company_id
    end
    company_id
  end

end
