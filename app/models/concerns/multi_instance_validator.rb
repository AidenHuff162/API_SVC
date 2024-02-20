class MultiInstanceValidator < ActiveModel::Validator
  def validate record
    invalid_multi_instance(record)
  end

  def invalid_multi_instance record
    record.errors.add(:instances, I18n.t('errors.invalid_multi_instance').to_s) if !['trinet', 'gusto', 'lever', 'xero'].include?(record.api_identifier) && IntegrationInstance.where(api_identifier: record.api_identifier, company_id: record.company_id).length >= 1
  end
end