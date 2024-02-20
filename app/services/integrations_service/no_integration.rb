class IntegrationsService::NoIntegration < IntegrationsService::Integration
  attr_reader :company, :custom_field_service

  def initialize(company)
    @company = company
    @custom_field_service = CustomFieldsService.new(company)
  end

  def manage_profile_setup_on_integration_change
    manage_custom_fields_on_integration_change
  end

  def manage_phone_data_migration_on_integration_change
    migrate_international_phone_data_to_simple_phone_format
  end

  private

  def manage_custom_fields_on_integration_change
    remove_preference_field('Job Tier')
  end

end
