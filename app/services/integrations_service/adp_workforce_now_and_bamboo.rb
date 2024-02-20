class IntegrationsService::AdpWorkforceNowAndBamboo < IntegrationsService::Integration
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

  private

  def manage_custom_groups_on_integration_change
    create_business_unit_custom_group
    create_division_custom_group
    update_custom_group_mapping_keys
  end

  def manage_custom_fields_on_integration_change
    create_custom_fields
    remove_preference_field('Job Tier')
    migrate_custom_field_data_to_another_field
  end

  def create_business_unit_custom_group
    params = {
      name: 'Business Unit',
      section: CustomField.sections[:private_info],
      integration_group: CustomField.integration_groups[:adp_wfn],
      field_type: CustomField.field_types[:mcq],
      mapping_key: 'Business Unit',
      collect_from: CustomField.collect_froms[:manager],
      deleted_at: nil,
      locks: { all_locks: true },
      company_id: @company.id
    }
    @custom_field_service.create_custom_groups_on_integration_change(params)
  end

  def create_division_custom_group
    params = {
      name: 'Division',
      section: CustomField.sections[:private_info],
      integration_group: CustomField.integration_groups[:adp_wfn],
      field_type: CustomField.field_types[:mcq],
      mapping_key: 'Division',
      collect_from: CustomField.collect_froms[:manager],
      deleted_at: nil,
      locks: { all_locks: true },
      company_id: @company.id
    }
    @custom_field_service.create_custom_groups_on_integration_change(params)
  end

  def create_custom_fields
    if !@custom_field_service.is_compensation_table_exists?
      params = {
        name: 'Pay Frequency',
        section: CustomField.sections[:private_info],
        field_type: CustomField.field_types[:mcq],
        collect_from: CustomField.collect_froms[:admin]
      }
      options = []
      @custom_field_service.create_custom_field_if_not_exists(params, options)

      params[:name] = 'Rate Type'
      options =  [ 'Daily', 'Hourly', 'Salary' ]
      @custom_field_service.create_custom_field_if_not_exists(params, options)

      params[:name] = 'Pay Rate'
      params[:field_type] = CustomField.field_types[:currency]
      @custom_field_service.create_custom_field_if_not_exists(params)
    end
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
