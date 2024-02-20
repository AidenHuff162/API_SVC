class HrisIntegrationsService::Deputy::DataBuilder
  attr_reader :parameter_mappings

  delegate :get_mapped_location_id, :get_mapped_gender_code, :get_mapped_home_address, :custom_table_based_mapping?, :fetch_custom_table, :get_mapped_currency_value, to: :helper_service

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_data(user)
    data = {}

    data[:strFirstName] = user.first_name if @parameter_mappings[:strFirstName].to_s == 'first name'
    data[:strLastName] = user.last_name if @parameter_mappings[:strLastName].to_s == 'last name'
    data[:strEmail] = user.email if @parameter_mappings[:strEmail].to_s == 'email'
    data[:strStartDate] = user.start_date.strftime('%Y-%m-%d') if @parameter_mappings[:strStartDate].to_s == 'start date'
    
    data[:strDob] = user.get_custom_field_value_text(@parameter_mappings[:strDob]).to_date.strftime('%Y-%m-%d') rescue nil if @parameter_mappings[:strDob].present?
    data[:strMobilePhone] = handle_phone_field(user.get_custom_field_value_text(@parameter_mappings[:strMobilePhone])) if @parameter_mappings[:strMobilePhone].present?
    data[:strEmergencyAddressContactName] = user.get_custom_field_value_text(@parameter_mappings[:strEmergencyAddressContactName]) if @parameter_mappings[:strEmergencyAddressContactName].present?
    data[:strEmergencyAddressPhone] = handle_phone_field(user.get_custom_field_value_text(@parameter_mappings[:strEmergencyAddressPhone])) if @parameter_mappings[:strEmergencyAddressPhone].present?

    data[:intCompanyId] = get_mapped_location_id(user) if @parameter_mappings[:intCompanyId].to_s == 'location id'
    data[:intGender] = get_mapped_gender_code(user.get_custom_field_value_text(@parameter_mappings[:intGender])) if @parameter_mappings[:intGender].present?
    
    if custom_table_based_mapping?(user.company, CustomTable.custom_table_properties[:compensation])
      custom_table = fetch_custom_table(user.company, CustomTable.custom_table_properties[:compensation])

      data[:fltAnnualSalary] = get_mapped_currency_value(user.get_custom_field_value_text(nil, true, nil, fetch_custom_field(custom_table, @parameter_mappings[:fltAnnualSalary]))) if @parameter_mappings[:fltAnnualSalary].present?
      data[:fltWeekdayRate] = get_mapped_currency_value(user.get_custom_field_value_text(nil, true, nil, fetch_custom_field(custom_table, @parameter_mappings[:fltWeekdayRate]))) if @parameter_mappings[:fltWeekdayRate].present?
      data[:fltSaturdayRate] = get_mapped_currency_value(user.get_custom_field_value_text(nil, true, nil, fetch_custom_field(custom_table, @parameter_mappings[:fltSaturdayRate]))) if @parameter_mappings[:fltSaturdayRate].present?
      data[:fltSundayRate] = get_mapped_currency_value(user.get_custom_field_value_text(nil, true, nil, fetch_custom_field(custom_table, @parameter_mappings[:fltSundayRate]))) if @parameter_mappings[:fltSundayRate].present?
      data[:fltPublicHolidayRate] = get_mapped_currency_value(user.get_custom_field_value_text(nil, true, nil, fetch_custom_field(custom_table, @parameter_mappings[:fltPublicHolidayRate]))) if @parameter_mappings[:fltPublicHolidayRate].present?
    else
      data[:fltAnnualSalary] = get_mapped_currency_value(user.get_custom_field_value_text(@parameter_mappings[:fltAnnualSalary], true)) if @parameter_mappings[:fltAnnualSalary].present?
      data[:fltWeekdayRate] = get_mapped_currency_value(user.get_custom_field_value_text(@parameter_mappings[:fltWeekdayRate], true)) if @parameter_mappings[:fltWeekdayRate].present?
      data[:fltSaturdayRate] = get_mapped_currency_value(user.get_custom_field_value_text(@parameter_mappings[:fltSaturdayRate], true)) if @parameter_mappings[:fltSaturdayRate].present?
      data[:fltSundayRate] = get_mapped_currency_value(user.get_custom_field_value_text(@parameter_mappings[:fltSundayRate], true)) if @parameter_mappings[:fltSundayRate].present?
      data[:fltPublicHolidayRate] = get_mapped_currency_value(user.get_custom_field_value_text(@parameter_mappings[:fltPublicHolidayRate], true)) if @parameter_mappings[:fltPublicHolidayRate].present?
    end

    if @parameter_mappings[:homeAddress].present?
      home_address = get_mapped_home_address(user.get_custom_field_value_text(@parameter_mappings[:homeAddress], true))
      if home_address.present?
        data.merge!(home_address)
      end
    end

    data
  end

  def build_update_profile_data(user, attributes)
    data = {}
    return data unless attributes.present? || attributes.length < 1
    
    attributes.each do |attribute|
      attribute = attribute.downcase

      data[:strFirstName] = user.first_name if @parameter_mappings[:strFirstName].to_s == attribute
      data[:strLastName] = user.last_name if @parameter_mappings[:strLastName].to_s == attribute
      data[:strEmail] = user.email if @parameter_mappings[:strEmail].to_s == attribute
      data[:strStartDate] = user.start_date.strftime('%Y-%m-%d') if @parameter_mappings[:strStartDate].to_s == attribute
      
      data[:strDob] = user.get_custom_field_value_text(@parameter_mappings[:strDob]).to_date.strftime('%Y-%m-%d') rescue nil if @parameter_mappings[:strDob].to_s == attribute
      data[:strMobilePhone] = handle_phone_field(user.get_custom_field_value_text(@parameter_mappings[:strMobilePhone])) if @parameter_mappings[:strMobilePhone].to_s == attribute
      data[:strEmergencyAddressContactName] = user.get_custom_field_value_text(@parameter_mappings[:strEmergencyAddressContactName]) if @parameter_mappings[:strEmergencyAddressContactName].to_s == attribute
      data[:strEmergencyAddressPhone] = handle_phone_field(user.get_custom_field_value_text(@parameter_mappings[:strEmergencyAddressPhone])) if @parameter_mappings[:strEmergencyAddressPhone].to_s == attribute

      data[:intCompanyId] = get_mapped_location_id(user) if @parameter_mappings[:intCompanyId].to_s == attribute
      data[:intGender] = get_mapped_gender_code(user.get_custom_field_value_text(@parameter_mappings[:intGender])) if @parameter_mappings[:intGender].to_s == attribute
      
      if custom_table_based_mapping?(user.company, CustomTable.custom_table_properties[:compensation])
        custom_table = fetch_custom_table(user.company, CustomTable.custom_table_properties[:compensation])

        data[:fltAnnualSalary] = get_mapped_currency_value(user.get_custom_field_value_text(nil, true, nil, fetch_custom_field(custom_table, @parameter_mappings[:fltAnnualSalary]))) if @parameter_mappings[:fltAnnualSalary].to_s == attribute
        data[:fltWeekdayRate] = get_mapped_currency_value(user.get_custom_field_value_text(nil, true, nil, fetch_custom_field(custom_table, @parameter_mappings[:fltWeekdayRate]))) if @parameter_mappings[:fltWeekdayRate].to_s == attribute
        data[:fltSaturdayRate] = get_mapped_currency_value(user.get_custom_field_value_text(nil, true, nil, fetch_custom_field(custom_table, @parameter_mappings[:fltSaturdayRate]))) if @parameter_mappings[:fltSaturdayRate].to_s == attribute
        data[:fltSundayRate] = get_mapped_currency_value(user.get_custom_field_value_text(nil, true, nil, fetch_custom_field(custom_table, @parameter_mappings[:fltSundayRate]))) if @parameter_mappings[:fltSundayRate].to_s == attribute
        data[:fltPublicHolidayRate] = get_mapped_currency_value(user.get_custom_field_value_text(nil, true, nil, fetch_custom_field(custom_table, @parameter_mappings[:fltPublicHolidayRate]))) if @parameter_mappings[:fltPublicHolidayRate].to_s == attribute
      else
        data[:fltAnnualSalary] = get_mapped_currency_value(user.get_custom_field_value_text(@parameter_mappings[:fltAnnualSalary], true)) if @parameter_mappings[:fltAnnualSalary].to_s == attribute
        data[:fltWeekdayRate] = get_mapped_currency_value(user.get_custom_field_value_text(@parameter_mappings[:fltWeekdayRate], true)) if @parameter_mappings[:fltWeekdayRate].to_s == attribute
        data[:fltSaturdayRate] = get_mapped_currency_value(user.get_custom_field_value_text(@parameter_mappings[:fltSaturdayRate], true)) if @parameter_mappings[:fltSaturdayRate].to_s == attribute
        data[:fltSundayRate] = get_mapped_currency_value(user.get_custom_field_value_text(@parameter_mappings[:fltSundayRate], true)) if @parameter_mappings[:fltSundayRate].to_s == attribute
        data[:fltPublicHolidayRate] = get_mapped_currency_value(user.get_custom_field_value_text(@parameter_mappings[:fltPublicHolidayRate], true)) if @parameter_mappings[:fltPublicHolidayRate].to_s == attribute
      end

      if @parameter_mappings[:homeAddress].to_s == attribute
        home_address = get_mapped_home_address(user.get_custom_field_value_text(@parameter_mappings[:homeAddress], true)) 
        if home_address.present?
          data.merge!(home_address)
        end
      end
    end
    
    data
  end

  def build_rehire_profile_data(user)
    build_create_profile_data(user)
  end

  private

  def fetch_custom_field(custom_table, field_name)
    custom_table.custom_fields.where('name ILIKE ?', field_name).take
  end

  def handle_phone_field(value)
    value && value.start_with?("'+") ? value[1..-1] : value
  end
  
  def helper_service
    HrisIntegrationsService::Deputy::Helper.new
  end
end
