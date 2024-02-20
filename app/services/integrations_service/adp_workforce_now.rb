class IntegrationsService::AdpWorkforceNow < IntegrationsService::Integration
  attr_reader :company, :custom_field_service, :integration_custom_table_service

  def initialize(company)
    super(company)
    @company = company
    @custom_field_service = CustomFieldsService.new(company)
    @integration_custom_table_service = IntegrationsService::ManageIntegrationCustomTables.new(company)
  end

  def manage_profile_setup_on_integration_change
    manage_custom_groups_on_integration_change
    manage_custom_fields_on_integration_change
  end

  def manage_phone_data_migration_on_integration_change
    migrate_simple_phone_date_to_international_phone_format
  end

  def manage_fields_and_groups_setup_on_integration_change(integration)
    if ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| @company.integration_types.include?(api_name) }.present?
      manage_sin_expiry_date_custom_field if @company.integration_types.include?('adp_wfn_can')
      create_worked_in_country_custom_field(integration) if !@company.adp_v2_migration_feature_flag
      update_sapling_option_mappings_from_adp(integration) if integration.client_id.present? && integration.client_secret.present?
      update_adp_onboarding_templates(integration) if integration.client_id.present? && integration.client_secret.present?
      manage_company_codes_custom_field(integration) if integration.enable_company_code
      manage_tax_types_custom_field(integration) if integration.enable_tax_type
    end
  end

  def manage_sin_expiry_date_custom_field
    create_sin_expiry_date_custom_field
  end

  def manage_company_codes_custom_field(integration)
    create_company_codes_custom_field(integration)
    ::HrisIntegrations::AdpWorkforceNow::UpdateCompanyCodesFromAdpJob.perform_later(integration.id)
  end

  def manage_tax_types_custom_field(integration)
    create_tax_types_custom_field(integration)
  end

  def update_sapling_option_mappings_from_adp(integration)
    ::HrisIntegrations::AdpWorkforceNow::UpdateSaplingIntegrationOptionMappingsFromAdpJob.perform_later(integration.id, true)
  end

  def update_adp_onboarding_templates(integration)
    ::HrisIntegrations::AdpWorkforceNow::UpdateOnboardingTemplatesFromAdpJob.perform_later(integration.id)
  end

  def create_company_codes_custom_field(integration_type)
    create_company_code_custom_group(integration_type)
  end

  def create_tax_types_custom_field(integration_type)
    create_tax_type_custom_group(integration_type)
  end

  def create_worked_in_country_custom_field(integration_type)
    create_worked_in_country_custom_group(integration_type)
    ::HrisIntegrations::AdpWorkforceNow::UpdateCountryAlphaCodesFromAdpJob.perform_later(integration_type.id)
  end

  def create_sin_expiry_date_custom_field(); create_sin_expiry_date() end

  private

  def manage_custom_groups_on_integration_change
    create_business_unit_custom_group
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
      integration_group: CustomField.integration_groups[:adp_wfn],
      field_type: CustomField.field_types[:mcq],
      mapping_key: 'Business Unit',
      collect_from: CustomField.collect_froms[:manager],
      deleted_at: nil,
      locks: { all_locks: true },
      company_id: @company.id
    }
    custom_table = integration_custom_table_service.fetch_custom_table(CustomTable.custom_table_properties[:role_information])
    if custom_table.present?
      params[:custom_table_id] = custom_table.id
    else
      params[:section] = CustomField.sections[:private_info]
    end

    @custom_field_service.create_custom_groups_on_integration_change(params)
  end

  def create_company_code_custom_group(integration_type)
    params = {
      name: 'ADP Company Code',
      field_type: CustomField.field_types[:mcq],
      mapping_key: 'Company Codes',
      collect_from: CustomField.collect_froms[:admin],
      deleted_at: nil,
      locks: { all_locks: true },
      company_id: @company.id,
      display_location: CustomField.display_locations[:onboarding]
    }
    custom_table = integration_custom_table_service.fetch_custom_table(CustomTable.custom_table_properties[:role_information])
    if custom_table.present?
      params[:custom_table_id] = custom_table.id
    else
      params[:section] = CustomField.sections[:personal_info]
    end

    @custom_field_service.create_custom_groups_on_integration_change(params)
  end

  def create_tax_type_custom_group(integration_type)
     custom_section= @company.custom_sections.find_by(section: CustomSection.sections[:personal_info])
    params = {
      name: 'Tax',
      field_type: CustomField.field_types[:tax],
      collect_from: CustomField.collect_froms[:admin],
      company_id: @company.id,
      display_location: CustomField.display_locations[:onboarding],
      section: custom_section.section,
      custom_section_id: custom_section.id
    } 

    options= []
    @custom_field_service.create_custom_field_if_not_exists(params, options, true)
  end

  def create_worked_in_country_custom_group(integration_type)
    params = {
      name: 'Worked in Country',
      field_type: CustomField.field_types[:mcq],
      collect_from: CustomField.collect_froms[:admin],
      locks: { all_locks: true },
      company_id: @company.id,
      display_location: CustomField.display_locations[:onboarding],
      section: CustomField.sections[:personal_info]
    }
    @custom_field_service.create_custom_groups_on_integration_change(params)
  end

  def create_sin_expiry_date()
     custom_section= @company.custom_sections.find_by(section: CustomSection.sections[:personal_info])
    params = {
      name: 'SIN Expiry Date',
      field_type: CustomField.field_types[:date],
      collect_from: CustomField.collect_froms[:new_hire],
      locks: { all_locks: true },
      company_id: @company.id,
      display_location: CustomField.display_locations[:onboarding],
      section: CustomField.sections[:personal_info],
      custom_section_id: custom_section.id
    }
    @custom_field_service.create_custom_groups_on_integration_change(params)
  end

  def create_custom_fields
    custom_table = integration_custom_table_service.fetch_custom_table(CustomTable.custom_table_properties[:compensation])
    if custom_table.blank?
      params = {
        name: 'Pay Frequency',
        field_type: CustomField.field_types[:mcq],
        collect_from: CustomField.collect_froms[:admin],
        section: CustomField.sections[:private_info]
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

    options = [ 'Civil Partnership', 'Domestic Partner', 'Separated', 'Divorced', 'Legally Separated',
      'Married', 'Domestic Partner', 'Single', 'Widowed' ]
    migrate_custom_field_data('Federal Marital Status', options)

    options = [ 'Male', 'Female', 'Not Specified' ]
    migrate_custom_field_data('Gender', options)
  end
end
