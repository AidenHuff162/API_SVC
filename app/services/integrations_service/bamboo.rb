class IntegrationsService::Bamboo < IntegrationsService::Integration
  attr_reader :company, :custom_field_service

  def initialize(company)
    super(company)

    @company = company
    @custom_field_service = CustomFieldsService.new(company)
  end

  def manage_profile_setup_on_integration_change
    manage_custom_groups_on_integration_change
    manage_custom_fields_on_integration_change
  end

  def manage_phone_data_migration_on_integration_change
    migrate_international_phone_data_to_simple_phone_format
  end

  def manage_fields_and_groups_on_integration_change(integration)
    if @company.integration_types.include?('bamboo_hr')
      update_sapling_groups_from_bamboo if integration.api_identifier == 'bamboo_hr' && integration.api_key.present? && integration.subdomain.present?
    end
  end

  private

  def update_sapling_groups_from_bamboo
    ::HrisIntegrations::Bamboo::UpdateSaplingGroupsFromBambooJob.perform_later(@company)
  end

  def manage_custom_groups_on_integration_change
    create_division_custom_group
    update_custom_group_mapping_keys
  end

  def manage_custom_fields_on_integration_change
    remove_preference_field('Job Tier')
    migrate_custom_field_data_to_another_field
  end

  def create_division_custom_group
    params = {
      name: 'Division',
      section: CustomField.sections[:private_info],
      integration_group: CustomField.integration_groups[:bamboo],
      field_type: CustomField.field_types[:mcq],
      mapping_key: 'Division',
      collect_from: CustomField.collect_froms[:manager],
      deleted_at: nil,
      locks: { all_locks: true },
      company_id: @company.id
    }
    @custom_field_service.create_custom_groups_on_integration_change(params)
  end

  def migrate_custom_field_data_to_another_field
    options = [ 'American Indian or Alaska Native', 'Asian', 'Black or African American', 'Hispanic or Latino',
      'Native Hawaiian or Other Pacific Islander', 'Two or more races', 'White' ]
    migrate_custom_field_data('Race/Ethnicity', options)

    options = [ 'Single','Married', 'Common Law', 'Domestic Partnership' ]
    migrate_custom_field_data('Federal Marital Status', options)

    options = [ 'Male', 'Female' ]
    migrate_custom_field_data('Gender', options)
  end
end
