class IntegrationsService::Namely < IntegrationsService::Integration
  attr_reader :company, :custom_field_service

  def initialize(company)
    super(company)
    @company = company
    @custom_field_service = CustomFieldsService.new(company)
  end

  def update_home_group
    update_home_group_field
  end
     
  def update_sapling_Custom_groups
    update_sapling_Custom_groups_from_namely
  end

  def update_sapling_department_and_locations
    update_sapling_department_and_locations_from_namely
  end

  def manage_profile_setup_on_integration_change
    manage_custom_fields_on_integration_change
  end

  def fetch_users
    fetch_namely_users
  end

  private

  def fetch_namely_users
    ::HrisIntegrations::Namely::UpdateSaplingUserFromNamelyJob.perform_async(@company.id)
  end

  def update_home_group_field
    @company.update_home_group_field
  end

  def update_sapling_department_and_locations_from_namely
    ::UpdateSaplingDepartmentsAndLocationsFromNamelyJob.perform_now(nil, @company)
  end

  def update_sapling_Custom_groups_from_namely
    ::UpdateSaplingCustomGroupsFromNamelyJob.perform_now(@company)
  end

  def manage_custom_fields_on_integration_change
    create_preference_fields
    migrate_custom_field_data_to_another_field
  end

  def create_preference_fields
    preferences = @company.prefrences
    default_fields = preferences['default_fields']

    if !@custom_field_service.is_preference_field_exists?(default_fields, 'Job Tier')
      default_fields.push({'id' => 'jbt', 'name' => 'Job Tier', 'api_field_id' => 'job_tier', 'section' => 'personal_info',
        'position' =>  @custom_field_service.find_max_position(CustomField.sections[:personal_info]), 'isDefault' => true,
        'editable' => false, 'enabled' => true, 'field_type' => 'short_text',  'collect_from' => 'admin', 'can_be_collected' => false,
        'visibility' => true, 'profile_setup' => 'profile_fields', 'deletable' => false})
      @company.update_column(:prefrences, preferences)
    end
  end

  def migrate_custom_field_data_to_another_field
    options = [ 'Hispanic or Latino', 'White (Not Hispanic or Latino)', 'Black or African American (Not Hispanic or Latino)',
    'Native Hawaiian or Other Pacific Islander (Not Hispanic or Latino)', 'Asian (Not Hispanic or Latino)', 'American Indian or Alaska Native (Not Hispanic or Latino)',
    'Two or more races (Not Hispanic or Latino)', 'Prefer Not to Disclose' ]
    custom_field = @company.custom_fields.where('name ILIKE ?', "Race/Ethnicity").first
    params = custom_field.attributes.symbolize_keys.slice(:section, :position, :name,
      :help_text, :required, :required_existing, :collect_from, :locks,
      :field_type, :custom_section_id)
    params[:name] = "Race/Ethnicity"
    params[:field_type] = CustomField.field_types[:mcq] if options.present?
    @custom_field_service.create_custom_field_if_not_exists(params, options, true)

    custom_field = @company.custom_fields.where('name ILIKE ?', "Federal Marital Status").first
    params = custom_field.attributes.symbolize_keys.slice(:section, :position, :name,
      :help_text, :required, :required_existing, :collect_from, :locks,
      :field_type, :custom_section_id)
    params[:field_type] = CustomField.field_types[:mcq] if options.present?
    params[:name] = "Federal Marital Status"
    options = [ 'Single', 'Married', 'Civil Partnership', 'Separated', 'Divorced' ]
    @custom_field_service.create_custom_field_if_not_exists(params, options, true)

    custom_field = @company.custom_fields.where('name ILIKE ?', "Gender").first
    params = custom_field.attributes.symbolize_keys.slice(:section, :position, :name,
      :help_text, :required, :required_existing, :collect_from, :locks,
      :field_type, :custom_section_id)
    params[:field_type] = CustomField.field_types[:mcq] if options.present?
    params[:name] = "Gender"
    options = [ 'Male', 'Female', 'Not Specified' ]
    @custom_field_service.create_custom_field_if_not_exists(params, options, true)
  end
end
