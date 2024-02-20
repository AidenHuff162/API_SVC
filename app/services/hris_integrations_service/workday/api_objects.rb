module HrisIntegrationsService::Workday::ApiObjects
  include HrisIntegrationsService::Workday::Exceptions

  def reference_object(id, type)
    return if id.blank? || type.blank? # to compact out the reference object if it doesn't have id value

    { ID: id, attributes!: { ID: { 'bsvc:type': type } } }
  end

  def user_reference_object(user)
    reference_object(user.workday_id, user.workday_id_type)
  end

  def response_filter(**kwargs)
    { As_Of_Effective_Date: (Date.today + 24.months), Page: nil, Count: 100 }.merge(kwargs).compact
  end

  def response_group(**kwargs)
    {
      Include_Personal_Information: true, Include_Employment_Information: true,
      Include_Related_Persons: true, Include_Photo: false, Include_Organizations: true,
      Exclude_Business_Units: false, Show_All_Personal_Information: true
    }.merge(kwargs).compact
  end

  def request_criteria(**kwargs)
    params = {
      Exclude_Employees: kwargs[:ee],
      Exclude_Contingent_Workers: kwargs[:ecw],
      Exclude_Inactive_Workers: fetch_all_departments
    }.compact
    if kwargs[:updated_from] || kwargs[:updated_through]
      params[:Transaction_Log_Criteria_Data] = {
        Transaction_Date_Range_Data: { Updated_From: kwargs[:updated_from], Updated_Through: kwargs[:updated_through] }.compact
      }
    end
    params
  end

  def business_process_parameters(auto_complete, run_now)
    { Auto_Complete: auto_complete, Run_Now: run_now }
  end

  def usage_data(id, type, is_primary)
    { Type_Data: { Type_Reference: reference_object(id, type) },
      attributes!: { Type_Data: { 'bsvc:Primary': is_primary } } }
  end

  def attribute_hash(name, value)
    { "bsvc:#{name}".to_sym => value }
  end

  def build_personal_information_data
    build_workday_element_from_custom_fields do |field_name, data_values|
      merge_ref_hash = %i[gender ethnicity marital_status citizenship_data].include?(field_name)
      merge_ref_hash ? reference_hash(field_name.to_s, data_values[field_name]) : self.send("#{field_name}_hash", data_values[field_name])
    end
  end

  def build_workday_element_from_custom_fields
    data_hash = {}
    return data_hash if custom_field_names.blank?

    custom_field_names.each do |field_name|
      next if data_values[field_name].blank?

      data_hash.merge!(yield(field_name, data_values))
    end
    data_hash
  end

  def reference_hash(field_name, data)
    return { Citizenship_Reference: citizenship_array(data) } if field_name == 'citizenship_data'

    { "#{field_name.titleize.tr(' ', '_')}_Reference": reference_object(data, 'WID') }
  end

  def citizenship_array(data)
    [reference_object(data[:citizenship_country], 'WID'), reference_object(data[:citizenship_type], 'WID')]
  end

  def date_of_birth_hash(data)
    { Date_of_Birth: data }
  end

  def disability_hash(data)
    # return {} unless (disability_wid = reference_object(data, 'WID'))

    {
      Disability_Information_Data: {
        Disability_Status_Information_Data: {
          Disability_Status_Data: { Disability_Reference: reference_object(data, 'WID') }# disability_wid }
        },
        attributes!: { Disability_Status_Information_Data: attribute_hash('Delete', false) }
      },
      attributes!: { Disability_Information_Data: attribute_hash('Replace_All', true) }
    }
  end

  def military_service_hash(data)
    {
      Military_Information_Data: {
        Military_Service_Information_Data: {
          Military_Service_Data: { Military_Status_Reference: reference_object(data, 'WID') }
        },
        attributes!: { Military_Service_Information_Data: attribute_hash('Delete', false) }
      },
      attributes!: { Military_Information_Data: attribute_hash('Replace_All', true) }
    }
  end

  def phone_number_field_names
    %i[home_phone_number mobile_phone_number]
  end

  def phone_type_hash
    { home_phone_number: 'Landline', mobile_phone_number: 'Mobile' }
  end

  def build_person_contact_information_data
    build_workday_element_from_custom_fields do |field_name, data_values|
      if phone_number_field_names.include?(field_name)
        phone_number(data_values)
      elsif address_field_names.include?(field_name)
        address_hash(data_values)
      else
        send("#{field_name}_hash", data_values)
      end
    end
  end

  def address_field_names
    %i[home_address shipping_address]
  end

  def address_field_type_hash
    { home_address: 'Home', shipping_address: 'Shipping'}
  end

  def address_hash(data_values)
    {
      Person_Address_Information_Data: {
        Address_Information_Data: address_info_data(data_values)
      },
      attributes!: { Person_Address_Information_Data: attribute_hash('Replace_All', false) }
    }
  end

  def address_info_data(data_values)
    (address_field_names & custom_field_names).map do |field_name|
      attr_id = address_field_type_hash[field_name]
      {
        Address_Data: {
          Country_Reference: reference_object(data_values[field_name][:country], 'ISO_3166-1_Alpha-2_Code'),
          Address_Line_Data: get_address_line_data(data_values[field_name]),
          attributes!: { Address_Line_Data: { 'bsvc:Type': get_address_line_data_type(data_values[field_name]) } },
          Country_Region_Reference: reference_object(data_values[field_name][:state], 'ISO_3166-2_Code'),
          Postal_Code: data_values[field_name][:zip],
          Municipality: data_values[field_name][:city]
        },
        Usage_Data: get_address_usage(field_name, attr_id),
        attributes!: { Usage_Data: attribute_hash('Public', false) }
      }
    end
  end

  def set_usage_for_shipping(usage_data)
    usage_data[:Use_For_Reference] = reference_object('Shipping','Communication_Usage_Behavior_ID')
  end

  def get_address_usage(field_name, attr_id)
    usage_data('Home', 'Communication_Usage_Type_ID', attr_primary?(attr_id)).tap { |usage_data| set_usage_for_shipping(usage_data) if field_name == :shipping_address }
  end

  def nationality_hash(country_name)
    {
      Primary_Nationality_Reference: reference_object(get_alpha2_country_code(country_name), 'ISO_3166-1_Alpha-2_Code')
    }
  end

  def attr_primary?(attr_id)
    ['Mobile', 'Home'].include?(attr_id)
  end

  def phone_number(data_values)
    {
      Person_Phone_Information_Data: {
        Phone_Information_Data: phone_info_data(data_values),
        attributes!: { Phone_Information_Data: attribute_hash('Delete', false) }
      },
      attributes!: { Person_Phone_Information_Data: attribute_hash('Replace_All', false) }
    }
  end

  def phone_info_data(data_values)
    (phone_number_field_names & custom_field_names).map do |phone_field|
      attr_id = phone_type_hash[phone_field]
      {
        Phone_Data: phone_data_hash(data_values[phone_field], attr_id),
        Usage_Data: usage_data('Home', 'Communication_Usage_Type_ID', attr_primary?(attr_id)),
        attributes!: { Usage_Data: attribute_hash('Public', false) }
      }
    end
  end

  def phone_data_hash(data, id)
    {
      Device_Type_Reference: reference_object(id, 'Phone_Device_Type_ID'),
      Country_Code_Reference: reference_object(data[:country], 'Country_Phone_Code_ID'),
      Complete_Phone_Number: "#{data[:area_code]}#{data[:phone]}"
    }
  end

  def personal_email_hash(data_values)
    {
      Person_Email_Information_Data: {
        Email_Information_Data: {
          Email_Data: { Email_Address: data_values[:personal_email] },
          Usage_Data: usage_data('Home', 'Communication_Usage_Type_ID', false),
          attributes!: { Usage_Data: attribute_hash('Public', false) }
        },
        attributes!: { Email_Information_Data: attribute_hash('Delete', false) }
      },
      attributes!: { Person_Email_Information_Data: attribute_hash('Replace_All', false) }
    }
  end

  def emergency_contacts_hash(data_values)
    contact_name, contact_number, contact_relationship = data_values[:emergency_contact_data].values_at(:contact_name, :contact_number, :contact_relationship)
    {
      Emergency_Contact_Data: {
        Primary: true, Priority: '1',
        Related_Person_Relationship_Reference: reference_object(contact_relationship, 'WID'),
        Emergency_Contact_Personal_Information_Data: {
          Person_Name_Data: person_name_hash(contact_name), Contact_Information_Data: contact_info_data_hash(contact_number)
        }.compact
      }
    }
  end

  def emergency_phone_data(data)
    return unless data.values_at(*%i[country country_code area_code phone]).all?

    {
      Country_ISO_Code: data[:country],
      International_Phone_Code: data[:country_code],
      Phone_Number: "#{data[:area_code]}#{data[:phone]}",
      Phone_Device_Type_Reference: reference_object('Mobile', 'Phone_Device_Type_ID'),
      Usage_Data: usage_data('Home', 'Communication_Usage_Type_ID', true),
      attributes!: { Usage_Data: attribute_hash('Public', false) }
    }
  end

  def contact_info_data_hash(data)
    return if (phone_data = emergency_phone_data(data)).blank?

    {
      Phone_Data: phone_data,
      attributes!: {
        Phone_Data: attribute_hash('Delete', false).merge!(attribute_hash('Do_Not_Replace_All', false))
      }
    }
  end

  def person_name_hash(data)
    return unless data[:first_name]

    {
      Legal_Name_Data: {
        Name_Detail_Data: {
          Country_Reference: reference_object('USA', 'ISO_3166-1_Alpha-3_Code'),
          First_Name: data[:first_name], Last_Name: data[:last_name]
        }.compact
      }
    }
  end


  def national_id_hash(id_data)
    {
      National_ID_Data: {
        ID: id_data[:id_number]&.gsub(/[-\s]/, ''),
        ID_Type_Reference: reference_object(id_data[:id_type], 'National_ID_Type_Code'),
        Country_Reference: reference_object(id_data[:id_country], 'ISO_3166-1_Alpha-3_Code'),
        Verification_Date: Date.today.strftime('%Y-%m-%d')
      }
    }
  end

  def get_eligible_for_hire(user)
    reference_object(user.eligible_for_rehire&.titleize, 'Yes_No_Type_ID') if user.workday_id_type == 'Employee_ID'
  end

  def terminate_event_data_hash(user, termination_reason)
    {
      Last_Day_of_Work: user.last_day_worked,
      Primary_Reason_Reference: reference_object(termination_reason, 'WID'),
      Eligible_for_Hire_Reference: get_eligible_for_hire(user)
    }.compact
  end

  # this function is specific to format data for i-9 and additional data request
  def get_formatted_field_value(user, field_name)
    return if (custom_field = CustomField.get_custom_field(user.company, field_name)).blank?

    case field_name
    when 'home address'
      get_address_hash(user.get_custom_field_value_text('home address', true))
    when 'mobile phone number'
      CustomField.convert_international_phone_number_to_phone_number(custom_field, user.id)
    when 'alien foreign passport country of issuance', 't-shirt size', 'nationality'
      field_value = CustomField.get_mcq_custom_field_value(custom_field, user.id)
      country_field?(field_name) ? get_alpha2_country_code(field_value) : field_value
    else
      return if (value = CustomField.get_custom_field_value(custom_field, user.id)).blank?

      custom_field.date? ? Time.parse(value).strftime('%Y-%m-%d') : value
    end
  end

  def form_i_9_section_1_data(user)
    address_hash = get_formatted_field_value(user, 'home address')
    {
      Employee_Last_Name: user.last_name,
      Employee_First_Name: user.first_name,
      Employee_Middle_Initial: get_formatted_field_value(user, 'middle name')&.at(0),
      Employee_Other_Names_Used: get_formatted_field_value(user, 'other last names used'),
      Employee_Address: address_hash[:line1],
      'Employee_Apt._Number': address_hash[:line2],
      Employee_City: address_hash[:city],
      Employee_State_Code: address_hash[:state],
      Employee_Zip_Code: address_hash[:zip],
      Employee_Date_of_Birth: get_formatted_field_value(user, 'date of birth'),
      Employee_Social_Security_Number: get_formatted_field_value(user, 'social security number'),
      Employee_Email_Address: user.email,
      Employee_Phone_Number: get_formatted_field_value(user, 'mobile phone number'),
      Citizenship_Status_Reference: reference_object(user.get_custom_field_value_workday_wid('I-9 Citizenship Status'), 'WID'),
      Employee_Signature_Date: Date.today.strftime('%Y-%m-%d'),
      Alien_Registration_Number_USCIS_Number: get_formatted_field_value(user, 'permanent resident or alien number/uscis number'),
      Alien_Authorized_to_Work_Until_Date: get_formatted_field_value(user, 'alien expiration date'),
      Country_of_Issuance_Reference: reference_object(get_formatted_field_value(user, 'alien foreign passport country of issuance'), 'ISO_3166-1_Alpha-2_Code'),
      Foreign_Passport_Number: get_formatted_field_value(user, 'foreign passport number'),
      'Form_I-94_Admission_Number': get_formatted_field_value(user, 'form i-94 admission number')
    }.compact
  end

  def form_i_9_section_2_data(user)
    {
      Worker_Start_Date: user.start_date,
      'Form_I-9_Employer_Signature_Date': Date.today.strftime('%Y-%m-%d'),
      'External_Form_I-9_Section_2_List_B_Data': get_section_2_list_data
    }
  end

  def get_section_2_list_data
    {
      # Document_Title_Reference: reference_object('', 'WID'),
      # DHS_Document_Title: '',
      # Document_Presented_as_Receipt: false,
      # Issuing_Authority_Reference: reference_object('', 'WID')
      # Document_Number: '',
      # Expiration_Date: ''
    }
  end

  def get_address_hash(address_hash)
    return {} if address_hash.blank? || (country = Country.find_by(name: address_hash[:country])).blank?
    address_hash[:state] &&= country.states.find_by(name: address_hash[:state]).key rescue nil
    address_hash
  end

  def country_field?(field_name)
    ['alien foreign passport country of issuance', 'nationality'].include?(field_name)
  end

  def get_base64_file(file_path)
    Base64.strict_encode64(open(file_path, &:read))
  end

  def get_creds_for_additional_data
    cred_fields = ['User Name', 'Password', 'Tenant Name']
    result_creds = cred_fields.map { |cred| get_integration_cred(cred) }
    validate_presence!('Tenant Name', result_creds.third)
    result_creds
  end

  def get_integration_cred(cred_name)
    credentials = user.company.get_integration('workday').integration_credentials
    credentials.by_name(cred_name).take&.value
  end

  def t_shirt_xml
    worker_id, worker_type, size = user.workday_id, user.workday_id_type, data_values[:t_shirt_size]
    user_name, password, tenant_name = get_creds_for_additional_data
    "<?xml version='1.0' encoding='UTF-8'?>
    <soapenv:Envelope
      xmlns:xsd='http://www.w3.org/2001/XMLSchema'
      xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'
      xmlns:bsvc='urn:com.workday/bsvc'
      xmlns:cus='urn:com.workday/tenants/#{tenant_name}/data/custom'
      xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/'>
      <soapenv:Header>
        <wsse:Security
          xmlns:wsse='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'>
          <wsse:UsernameToken wsu:Id='UsernameToken-1'
            xmlns:wsu='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'>
            <wsse:Username>#{user_name}</wsse:Username>
            <wsse:Password Type='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText'>#{password}</wsse:Password>
          </wsse:UsernameToken>
        </wsse:Security>
      </soapenv:Header>
      <soapenv:Body>
        <bsvc:Edit_Worker_Additional_Data_Request>
          <bsvc:Business_Process_Parameters>
            <bsvc:Auto_Complete>true</bsvc:Auto_Complete>
            <bsvc:Run_Now>true</bsvc:Run_Now>
          </bsvc:Business_Process_Parameters>
          <bsvc:Worker_Custom_Object_Data>
            <bsvc:Effective_Date>#{get_effective_date(user)}</bsvc:Effective_Date>
            <bsvc:Worker_Reference>
              <bsvc:ID bsvc:type='#{worker_type}'>#{worker_id}</bsvc:ID>
            </bsvc:Worker_Reference>
            <bsvc:Business_Object_Additional_Data>
              <cus:tshirt>
                <cus:size>
                  <cus:ID cus:type='ExtendedAlias'>#{size}</cus:ID>
                </cus:size>
              </cus:tshirt>
            </bsvc:Business_Object_Additional_Data>
          </bsvc:Worker_Custom_Object_Data>
        </bsvc:Edit_Worker_Additional_Data_Request>
      </soapenv:Body>
    </soapenv:Envelope>".squish.gsub('> <', '><')
  end

  def get_alpha2_country_code(country_name)
    Country.find_by(name: country_name)&.key
  end

  def get_effective_date(user)
    today, user_start_date = Date.today, user.start_date
    (user_start_date > today ? user_start_date : today).strftime('%Y-%m-%d')
  end

  def department_group_params
    return {} unless fetch_all_departments
    {
      Show_All_Personal_Information: false,
      Include_Employment_Information: false,
      Include_Related_Persons: false
    }
  end

end
