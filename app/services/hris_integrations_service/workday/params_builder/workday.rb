class HrisIntegrationsService::Workday::ParamsBuilder::Workday < ApplicationService
  include HrisIntegrationsService::Workday::ApiObjects
  attr_reader :request_name, :request_params, :user, :data_values, :custom_field_names, :fetch_all_departments

  def initialize(request_name, request_params)
    @request_name = request_name
    @request_params = request_params
    @user, @data_values, @custom_field_names = request_params.values_at(:user, :data_values, :custom_field_names)
    @fetch_all_departments = request_params[:fetch_all_departments]
  end

  def call
    send("#{request_name}_params", request_params)
  end

  private

  def fetch_worker_params(kwargs) # not using double splat operator due to its issue in Sidekiq job
    {
      Request_References: { Worker_Reference: reference_object(kwargs[:worker_id], kwargs[:worker_type]) },
      Response_Filter: response_filter(Count: nil),
      Response_Group: response_group(department_group_params)
    }
  end

  def fetch_employee_workers_params(kwargs)
    {
      Request_Criteria: request_criteria(ecw: true),
      Response_Filter: response_filter(Page: kwargs[:page]),
      Response_Group: response_group(department_group_params)
    }
  end

  def fetch_contingent_workers_params(kwargs)
    {
      Request_Criteria: request_criteria(ee: true),
      Response_Filter: response_filter(Page: kwargs[:page]),
      Response_Group: response_group(department_group_params)
    }
  end

  def fetch_recently_updated_employee_workers_params(kwargs)
    {
      Request_Criteria: request_criteria(ecw: true, updated_from: (DateTime.now - 2.days), updated_through: (DateTime.now)),
      Response_Filter: response_filter(Page: kwargs[:page]),
      Response_Group: response_group
    }
  end

  def fetch_recently_updated_contingent_workers_params(kwargs)
    {
      Request_Criteria: request_criteria(ee: true, updated_from: (DateTime.now - 2.days), updated_through: (DateTime.now)),
      Response_Filter: response_filter(Page: kwargs[:page]),
      Response_Group: response_group
    }
  end

  def change_legal_name_params(**kwargs) # for metaprogramming purposes, passing kwargs
    {
      Business_Process_Parameters: business_process_parameters(true, true),
      Change_Legal_Name_Data: {
        Person_Reference: user_reference_object(user),
        Effective_Date: get_effective_date(user),
        Name_Data: {
          Country_Reference: reference_object('US', 'ISO_3166-1_Alpha-2_Code'),
          First_Name: user.first_name, Last_Name: user.last_name,
          Middle_Name: data_values[:middle_name]
        }.compact
      }
    }
  end

  def change_preferred_name_params(**kwargs)
    {
      Business_Process_Parameters: business_process_parameters(true, true),
      Change_Preferred_Name_Data: {
        Person_Reference: user_reference_object(user),
        Name_Data: {
          Country_Reference: reference_object('US', 'ISO_3166-1_Alpha-2_Code'),
          First_Name: data_values[:preferred_name], Last_Name: user.last_name
        }
      }
    }
  end

  def change_personal_information_params(**kwargs)
    params = {
      Business_Process_Parameters: business_process_parameters(true, true),
      Change_Personal_Information_Data: { Person_Reference: user_reference_object(user) }
    }

    params[:Change_Personal_Information_Data][:Personal_Information_Data] = build_personal_information_data
    params
  end

  def change_home_contact_information_params(**kwargs)
    params = {
      Business_Process_Parameters: business_process_parameters(true, true),
      Change_Home_Contact_Information_Data: {
        Person_Reference: user_reference_object(user), Event_Effective_Date: get_effective_date(user)
      }
    }
    params[:Change_Home_Contact_Information_Data][:Person_Contact_Information_Data] = build_person_contact_information_data

    params
  end

  def change_emergency_contacts_params(**kwargs)
    {
      Business_Process_Parameters: business_process_parameters(true, true),
      Change_Emergency_Contacts_Data: {
        Person_Reference: user_reference_object(user), Replace_All: true,
        Emergency_Contacts_Reference_Data: emergency_contacts_hash(data_values)
      }
    }
  end

  def change_business_title_params(**kwargs)
    {
      Business_Process_Parameters: business_process_parameters(true, true),
      Change_Business_Title_Business_Process_Data: {
        Worker_Reference: user_reference_object(user),
        Change_Business_Title_Data: {
          Event_Effective_Date: get_effective_date(user), Proposed_Business_Title: data_values[:title]
        }
      }
    }
  end

  def change_government_i_ds_params(**kwargs)
    id_data = data_values[:national_id]
    {
      Business_Process_Parameters: business_process_parameters(true, true),
      Change_Government_IDs_Data: {
        Person_Reference: user_reference_object(user),
        Government_Identification_data: {
          National_ID: national_id_hash(id_data), attributes!: { National_ID: attribute_hash('Delete', false) }
        },
        attributes!: {
          Government_Identification_data: attribute_hash('Replace_All', true)
        }
      }
    }
  end

  def change_work_contact_information_params(**kwargs)
    {
      Business_Process_Parameters: business_process_parameters(true, true),
      Change_Work_Contact_Information_Data: {
        Person_Reference: user_reference_object(user),
        Event_Effective_Date: get_effective_date(user),
        Person_Contact_Information_Data: {
          Person_Email_Information_Data: {
            Email_Information_Data: {
              Email_Data: { Email_Address: data_values[:email] },
              Usage_Data: usage_data('WORK', 'Communication_Usage_Type_ID', true),
              attributes!: { Usage_Data: attribute_hash('Public', true) }
            },
            attributes!: { Email_Information_Data: attribute_hash('Delete', false) }
          },
          attributes!: { Person_Email_Information_Data: attribute_hash('Replace_All', false) }
        }
      }
    }
  end

  def change_person_photo_params(**kwargs)
    downloaded_image, encoded_image = data_values[:profile_image].values_at(:downloaded_image, :encoded_image)
    return {} if downloaded_image.blank?

    {
      Business_Process_Parameters: business_process_parameters(true, true),
      Person_Photo_Data: {
        Person_Reference: user_reference_object(user),
        Photo_Data: { Filename: downloaded_image.path.split('/').last, File: encoded_image }
      }
    }
  end

  def put_worker_document_params(**kwargs)
    return {} if (doc_data = data_values[:workday_document]).blank?
    {
      Worker_Document_Data: {
        ID: doc_data[:document_id], Filename: doc_data[:filename],
        File: get_base64_file(doc_data[:file_path]),
        Document_Category_Reference: reference_object(doc_data[:doc_category_wid], 'WID'),
        Worker_Reference: user_reference_object(user)
      }.compact # if file content doesn't exist, remove it from request
    }
  end

  def worker_employment_organization_data_params(**kwargs)
    {
      Request_References: { Worker_Reference: reference_object(kwargs[:workday_id], kwargs[:workday_id_type]) },
      Response_Filter: response_filter(Count: nil),
      Response_Group: response_group(Include_Personal_Information: false, Include_Related_Persons: false, Show_All_Personal_Information: false)
    }
  end

  def get_worker_photos_params(**kwargs)
    {
      Response_Filter: response_filter(Count: nil),
      Request_References: { Worker_Reference: reference_object(kwargs[:workday_id], kwargs[:workday_id_type]) }
    }
  end

  def terminate_employee_params(**kwargs)
    user = kwargs[:user]
    {
      Business_Process_Parameters: business_process_parameters(true, true),
      Terminate_Employee_Data: {
        Employee_Reference: reference_object(user.workday_id, 'Employee_ID'),
        Termination_Date: user.termination_date, Terminate_Event_Data: terminate_event_data_hash(user, kwargs[:termination_reason])
      }.compact
    }
  end

  def end_contingent_worker_contract_params(**kwargs)
    user = kwargs[:user]
    {
      Business_Process_Parameters: business_process_parameters(true, true),
      End_Contingent_Worker_Contract_Data: {
        Contingent_Worker_Reference: reference_object(user.workday_id, 'Contingent_Worker_ID'),
        Contract_End_Date: user.termination_date, End_Contract_Event_Data: terminate_event_data_hash(user, kwargs[:termination_reason])
      }.compact
    }
  end

  # def change_organization_assignments_params(**kwargs)
  #   {
  #     Business_Process_Parameters: business_process_parameters(true, true),
  #     Change_Organization_Assignments_Data: {
  #       Position_Reference: reference_object(user.workday_position_id, 'Position_ID'),
  #       Worker_Reference: user_reference_object(user),
  #       Position_Organization_Assignments_Data: {
  #         Cost_Center_Assignments_Reference: reference_object(get_cost_center_field_value(user), 'Organization_Reference_ID')
  #       }.compact
  #     }.compact
  #   }
  # end

  def put_external_form_i_9_params(**kwargs)
    {
      Business_Process_Parameters: business_process_parameters(true, true),
      'External_Form_I-9_Data' => {
        Worker_Reference: user_reference_object(user),
        'External_Form_I-9_Source_Reference' => reference_object(get_integration_cred('External Form I-9 Source WID'), 'WID'),
        'External_Form_I-9_Section_1_Data' => form_i_9_section_1_data(user),
        'External_Form_I-9_Section_2_Data' => form_i_9_section_2_data(kwargs[:user]),
        # 'External_Form_I-9_Attachment_Data' => get_form_i_9_file_obj(kwargs)
      }.compact
    }
  end

  def edit_worker_additional_data_params(**kwargs)
    custom_field_names.include?(:t_shirt_size) ? t_shirt_xml : ''
  end

  def put_external_disability_self_identification_record_params(**kwargs)
    return {} if (wid = data_values[:disability_status]).blank?

    {
      External_Disability_Self_Identification_Record_Data: {
        Employee_Reference: user_reference_object(user),
        Disability_Status_Reference: reference_object(wid, 'WID'),
        Invitation_Date: Date.today.strftime('%Y-%m-%d'),
        Response_Date: Date.today.strftime('%Y-%m-%d')
      }
    }
  end

  private

  def get_address_line_data(home_address)
    [home_address[:line1], home_address[:line2]].select(&:present?)
  end

  def get_address_line_data_type(home_address)
    line1, line2 = home_address[:line1], home_address[:line2]
    address_hash  = { ADDRESS_LINE_1: line1, ADDRESS_LINE_2: line2 }
    [line1, line2].select(&:present?).map{|b| address_hash.key(b).to_s}
  end

  # def get_cost_center_field_value(user)
  #   user.custom_field_values.joins(:custom_field).find_by(custom_fields: {name: 'Cost Center'}).custom_field_option.option rescue nil
  # end

end
