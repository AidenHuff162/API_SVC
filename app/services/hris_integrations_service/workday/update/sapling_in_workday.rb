class HrisIntegrationsService::Workday::Update::SaplingInWorkday < ApplicationService
  include HrisIntegrationsService::Workday::Logs

  attr_reader :user, :field_names, :company, :doc_file_hash, :helper_object, :worker_subtype_filters

  delegate :workday_operation_name, :get_worker_subtype_filters, to: :helper_object
  delegate :prepare_request, :sync_workday, to: :web_service

  def initialize(user, field_names, **kwargs)
    @user, @field_names, @company, @doc_file_hash = user, field_names.map(&:downcase), user.company, kwargs[:doc_file_hash]
    @helper_object = HrisIntegrationsService::Workday::Helper.new
    @worker_subtype_filters = get_worker_subtype_filters(company, user.workday_id_type)
  end

  def call
    update_workday_user
  end

  private

  def update_workday_user
    return unless should_proceed_to_workday?

    begin
      log_section_name = nil
      replace_fields_with_sub_custom_field_names
      build_section_hash.each do |section_name, section_params|
        log_section_name = section_name
        section_request_params = get_section_request_params(*section_params.values)
        execute_request(section_request_params, section_params[:attrs])
      end
      # format of section hash
      # :personal_information => {
      #            :field_names => [
      #             [0] "date of birth",
      #             [1] "disability",
      #             [2] "citizenship status"
      #         ],
      #                  :attrs => {
      #             :section_name => "personal_information",
      #                   :doc_file_hash => nil
      #         }
      #     }
    rescue Exception => @error
      error_log("Unable to update user with id (#{user.id}) in Workday",
                {}, { data: { section_name: log_section_name, field_names: field_names } })
    end
  end

  def should_proceed_to_workday?
    user&.workday_id && company.get_integration('workday')&.active?
  end

  def web_service
    @web_object ||= HrisIntegrationsService::Workday::WebService.new(company.id)
  end

  def execute_request(request_params, **kwargs)
    return if request_params.blank?

    begin
      response = nil
      request_type, operation_name = get_request_operation_name(kwargs[:section_name])
      response = prepare_request(operation_name, request_params, request_type)
      update_log(kwargs.merge({ status_code: response.http.code, request_params: request_params,
                                response: response, operation_name: operation_name }))
    rescue Exception => @error
      replace_logging_content(request_params, get_content_type(kwargs[:section_name]), :File)
      error_log("Unable to update user with id: (#{user.id}) in Workday",
                { response: response&.body }, api_action(operation_name, request_params))
    end
  end

  def get_request_operation_name(section_name)
    [staffing_operation_names.include?(section_name) ? 'staffing' : 'human_resource', workday_operation_name(section_name)]
  end

  def update_log(**kwargs)
    replace_logging_content(kwargs[:request_params], get_content_type(kwargs[:section_name]), :File)
    action = "#{log_result(kwargs[:status_code])} update #{kwargs[:section_name]} for user with id: #{user.id} in Workday"
    log(action, { response: kwargs[:response].body }, api_action(kwargs[:operation_name], kwargs[:request_params]), kwargs[:status_code])
    (kwargs[:status_code] == 500) && send_to_teams(action)
  end

  def get_content_type(section_name)
    { person_photo: :request_photo, worker_document: :request_file }[section_name.to_sym]
  end

  def staffing_operation_names
    %w[worker_document organization_assignments worker_additional_data]
  end

  def build_section_hash
    section_hash = custom_fields_per_section.dup
    section_hash.each do |k, v|
      (fields = (field_names & v)).any? ? (section_hash[k] = get_section_name_hash(k, fields)) : section_hash.delete(k)
    end
  end

  def attrs_hash(section_name)
    { section_name: section_name, doc_file_hash: doc_file_hash }
  end

  def get_section_name_hash(section_name, field_names)
    section_name = section_name.to_s
    { field_names: field_names, attrs: attrs_hash(section_name) }
  end

  def get_section_request_params(field_names, attrs)
    params = attrs.merge({ user: user, helper_object: helper_object, field_names: field_names })
    HrisIntegrationsService::Workday::DataBuilder::Workday.new(params).call
  end

  def replace_fields_with_sub_custom_field_names
    {
      # 'disability' => ['disability status', 'disability type']
    }.each do |field_name, sub_field_names|
      if field_names.include?(field_name)
        field_names.delete(field_name)
        field_names.append(*sub_field_names)
      end
    end
  end

  def custom_fields_per_section
    {
      # external_disability_self_identification_record: ['disability status'],
      personal_information: ['race/ethnicity', 'date of birth', 'disability', 'gender', 'federal marital status', 'military service', 'nationality', 'citizenship type', 'citizenship country'], # << 'disability type'
      legal_name: ['first name', 'last name', 'middle name'],
      home_contact_information: ['home phone number', 'mobile phone number', 'home address', 'personal email', 'shipping address (for packages/swag items)'],
      emergency_contacts: ['emergency contact name', 'emergency contact number', 'emergency contact relationship'],
      business_title: ['title'],
      work_contact_information: ['email'],
      government_i_ds: ['national id'],
      person_photo: ['profile image'],
      preferred_name: ['preferred name'],
      worker_document: ['upload_request', 'paperwork_request'],
      # organization_assignments: ['cost center'],
      external_form_i_9: ['form_i_9_request'],
      worker_additional_data: ['t-shirt size']
    }.freeze
  end

end
