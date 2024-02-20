class IntegrationsService::Integration
  attr_reader :company, :custom_field_service

  def initialize(company)
    @company = company
    @custom_field_service = CustomFieldsService.new(company)
  end

  def update_custom_group_mapping_keys
    @company.update_columns(department_mapping_key: 'Department', location_mapping_key: 'Location')
  end

  def migrate_international_phone_data_to_simple_phone_format
    custom_fields = @company.custom_fields.where(field_type: CustomField.field_types[:phone])

    custom_fields.try(:each) do |custom_field|
      ::Integrations::MigrateInternationalPhoneDataToSimplePhoneFormatJob.perform_later(@company.id, custom_field.id)
    end
  end

  def migrate_simple_phone_date_to_international_phone_format
    custom_fields = @company.custom_fields.where(field_type: CustomField.field_types[:simple_phone])

    custom_fields.try(:each) do |custom_field|
      ::Integrations::MigrateSimplePhoneDataToInternationalPhoneFormatJob.perform_later(@company.id, custom_field.id)
    end
  end

  def remove_preference_field(name)
    @custom_field_service.remove_preference_field(name)
  end

  def migrate_custom_field_data(custom_field_name, options = [])
    ::Integrations::MigrateCustomFieldDataToAnotherCustomFieldJob.perform_later(@company.id, custom_field_name, options)
  end
end
