class IntegrationsService::Paylocity < IntegrationsService::Integration
  attr_reader :company, :custom_field_service , :options

  def initialize(company)
    @company = company
    @custom_field_service = CustomFieldsService.new(company)
  end

  def manage_profile_setup_on_integration_change
    manage_custom_fields_on_integration_change
  end

  def manage_phone_data_migration_on_integration_change
    # migrate_simple_phone_date_to_international_phone_format
  end

  private

  def manage_custom_fields_on_integration_change
    create_preference_fields
    create_custom_fields
    remove_preference_field('Job Tier')
    # migrate_custom_field_data_to_another_field
  end

  def create_preference_fields
    preferences = @company.prefrences
    default_fields = preferences['default_fields']

    if !@custom_field_service.is_preference_field_exists?(default_fields, 'Paylocity ID')
      default_fields.push({"id" => "pi", "name" => "Paylocity ID", "api_field_id" => "paylocityid",
        "section" => "private_info", "isDefault" => true, "editable" => false, "enabled" => true,
        "field_type" => "short_text", "collect_from" => "admin", "can_be_collected" => true, "visibility" => true,
        "profile_setup" => "profile_fields", "position" => @custom_field_service.find_max_position(CustomField.sections[:private_info]),
        'deletable' => false, "custom_section_id" => @company.custom_sections.find_by(section: :private_info).id})
      @company.update_column(:prefrences, preferences)
    end
  end

  def create_custom_fields
    if !@custom_field_service.is_compensation_table_exists? 
      params = params_for_create_custom_field
      options = [ 'Daily', 'Weekly', 'Bi-weekly', 'Semi-Monthly', 'Monthly', 'Quarterly', 'Annual' ]
      @custom_field_service.create_custom_field_if_not_exists(params, options)

      params[:name] = 'Pay Type'
      options = [ 'Salary', 'Hourly' ]
      @custom_field_service.create_custom_field_if_not_exists(params, options)

      params[:name] = 'BaseRate'
      params[:field_type] = CustomField.field_types[:currency]
      @custom_field_service.create_custom_field_if_not_exists(params)

      params[:name] = 'Salary'
      params[:field_type] = CustomField.field_types[:currency]
      @custom_field_service.create_custom_field_if_not_exists(params)
      
      initializing_autoPay_value(params)
      
    else
      params = params_for_create_custom_field
      initializing_autoPay_value(params)
    end
    
    params = {
      name: 'Tax State',
      section: CustomField.sections[:private_info],
      field_type: CustomField.field_types[:mcq],
      collect_from: CustomField.collect_froms[:admin],
      locks: { all_locks: true },
      required: true
    }
    options = Country.find_by(key: "US").states.order('id ASC').pluck(:name) rescue []
    @custom_field_service.create_custom_field_if_not_exists(params, options)

    params[:name] = 'Tax Form'
    options = [ 'W2', '1099M', '1099R' ]
    @custom_field_service.create_custom_field_if_not_exists(params, options)

    params[:name] = 'Middle Name'
    params[:field_type] = CustomField.field_types[:short_text]
    @custom_field_service.create_custom_field_if_not_exists(params)

    cost_centers = ['Cost Center 1', 'Cost Center 2', 'Cost Center 3']
    cost_centers.each do |const_center|
      HrisIntegrationsService::Paylocity::CostCenters.new(const_center.downcase.delete(' '), company).fetch    
    end
  end

  def migrate_custom_field_data_to_another_field
    options = [ 'N/A' ]
    migrate_custom_field_data('Race/Ethnicity', options)

    options = [ 'Single', 'Married filing jointly', 'Married filing separately', 'Qualifying widow(er) with dependent child' ]
    migrate_custom_field_data('Federal Marital Status', options)

    options = [ 'Male', 'Female', 'Not Specified' ]
    migrate_custom_field_data('Gender', options)
  end
  
  def params_for_create_custom_field()
    params = {
      name: 'Pay Frequency',
      section: CustomField.sections[:private_info],
      field_type: CustomField.field_types[:mcq],
      collect_from: CustomField.collect_froms[:admin],
      locks: { all_locks: true },
      required: true
    }
  end

  def initializing_autoPay_value(params)
    params[:name] = 'Auto Pay'
    options = [ 'True', 'False' ]
    params[:field_type] = CustomField.field_types[:mcq]
    params[:locks] = { all_locks: false }
    
    if !@custom_field_service.is_compensation_table_exists?
      @custom_field_service.create_custom_field_if_not_exists(params, options)
    else
      custom_table = @company.custom_tables.where('custom_tables.custom_table_property = ?', CustomTable.custom_table_properties[:compensation])&.take
      if custom_table
        params[:section] = nil
        params.merge!(custom_table_id: custom_table.id)
      end
      @custom_field_service.create_custom_field_if_not_exists(params, options)
    end
  end
end
