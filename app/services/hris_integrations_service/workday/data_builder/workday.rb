class HrisIntegrationsService::Workday::DataBuilder::Workday
  include HrisIntegrationsService::Workday::Logs
  include HrisIntegrationsService::Workday::Exceptions

  attr_reader :company, :user, :field_names, :doc_file_hash, :section_name, :helper_object

  delegate :map_to_workday_address, :map_to_workday_phone, to: :field_options_mapper_service
  delegate :conflicted_custom_field_mapper, :workday_operation_name, to: :helper_object

  def initialize(**kwargs)
    extract_attrs = %i[user helper_object field_names doc_file_hash section_name]
    @user, @helper_object, @field_names, @doc_file_hash, @section_name = kwargs.values_at(*extract_attrs)
    @company = user.company
  end

  def call
    begin
      build_request_params(workday_operation_name(section_name), build_request_params_attrs)
    rescue Exception => @error
      error_log("Unable to create request data for user with id (#{user.id})",
                {}, { data: {field_names: field_names } })
      {}
    end
  end

  def get_updated_field_value(field_name)
    case field_name
    when 'mobile phone number', 'home phone number'
      map_to_workday_phone(user.get_custom_field_value_text(field_name, true))
    when 'home address', 'shipping address (for packages/swag items)'
      map_to_workday_address(user.get_custom_field_value_text(field_name, true))
    when 'personal email', 'last name', 'first name', 'title', 'email', 'preferred name'
      user.send(field_name.gsub(' ', '_'))
    when 'emergency contact name', 'emergency contact number', 'emergency contact relationship'
      get_emergency_contact_data
    when 'profile image'
      get_profile_image_data
    when 'upload_request'
      get_upload_request_doc_data
    when 'paperwork_request'
      get_paperwork_request_doc_data
    when 'national id'
      get_national_id_data
    when 'citizenship type', 'citizenship country'
      get_citizenship_data
    # when 'disability status', 'disability type'
    #   get_disability_data(field_name)
    else
      (wid?(field_name) ? user.get_custom_field_value_workday_wid(field_name) : user.get_custom_field_value_text(field_name))
    end
  end

  def get_emergency_contact_data
    return_hash = {}
    emergency_contact_name = user.get_custom_field_value_text('emergency contact name')
    return return_hash if emergency_contact_name.blank?

    first_name, last_name = emergency_contact_name.squish.split(/ /, 2)
    return_hash[:contact_name] = { first_name: first_name, last_name: last_name }
    return {} unless (contact_number = user.get_custom_field_value_text('emergency contact number', true)).values.all?(&:present?)

    contact_number[:country_code] = user.get_custom_field_value_text('emergency contact number', false, 'Country')
    return_hash[:contact_number] = contact_number
    return_hash[:contact_relationship] = user.get_custom_field_value_workday_wid('emergency contact relationship')

    return_hash
  end

  def get_profile_image_data
    return_hash = {}
    return return_hash unless user.profile_image&.file&.url

    image_path = "#{Rails.env.development? ? "#{Rails.root}/public" : ''}#{user.profile_image.file.url(:square_thumb)}"
    return_hash[:downloaded_image] = MiniMagick::Image.open(image_path)
    return_hash[:encoded_image] = Base64.strict_encode64(File.open(return_hash[:downloaded_image].path, 'rb').read)
    return_hash
  end

  def get_upload_request_doc_data
    doc_id, file_id = doc_file_hash.values_at(:doc_id, :file_id)
    return {} if (document = user.user_document_connections.find_by(id: doc_id)).blank?

    attached_files = document.attached_files
    attached_file = attached_files.find(file_id)
    filename = get_doc_filename(document)
    filename += " - Attachment##{attached_files.index(attached_file) + 1}" if attached_files.count > 1
    file_obj, local_env = attached_file.file, (Rails.env.test? || Rails.env.development?)
    file_path = (local_env ? file_obj.path : file_obj.download_url(filename))
    worker_doc_data_hash(document.id, filename, file_path)
  end

  def get_paperwork_request_doc_data
    return {} if (document = user.paperwork_requests.find_by(id: doc_file_hash[:doc_id])).blank?

    download_service = Interactions::Users::DownloadAllDocuments.new(user, '')
    filename = download_service.pdf_filename('paperwork_request', document)
    file_path = download_service.paperwork_download_url(document, filename)
    worker_doc_data_hash(document.id, filename, file_path)
  end

  def get_national_id_data
    return {} unless (id_data = user.get_custom_field_value_text('national id', true)).values.all?(&:present?)

    id_data[:id_country] = id_data[:id_type].split('-').first # id_type: USA-SSN, USA is the alpha3 code
    id_data
  end

  def get_disability_data(field_name)
    custom_field = CustomField.get_custom_field(company, 'disability')
    CustomField.get_sub_custom_field_value(custom_field, field_name, user.id)
  end

  def get_citizenship_data
    { citizenship_country: user.get_custom_field_value_workday_wid('citizenship country'),
      citizenship_type: user.get_custom_field_value_workday_wid('citizenship type') }.compact
  end

  def build_request_params_attrs
    request_params_attrs, custom_field_names = { user: user, data_values: {} }, []
    field_data_values.each do |field_data_value| # request_attr = { field_name: field name, data_value: data }
      next if field_data_value[:data_value].blank?

      field_name = get_field_name(field_data_value[:field_name])
      request_params_attrs[:data_values][field_name] = field_data_value[:data_value]
      custom_field_names << field_name
    end
    request_params_attrs[:custom_field_names] = custom_field_names.uniq
    request_params_attrs
  end

  def field_data_values
    field_names.map do |field_name|
      { field_name: field_name, data_value: get_updated_field_value(field_name) }
    end
  end

  def build_request_params(request_name, request_params)
    return {} if request_params[:data_values].blank?
    HrisIntegrationsService::Workday::ParamsBuilder::Workday.call(request_name, request_params)
  end

  def get_field_name(field_name)
    return :emergency_contact_data if emergency_contact_data?(field_name) # making the common key for emergency data
    return :workday_document if worker_document?(field_name)
    return :citizenship_data if citizenship_data?(field_name)

    conflicted_custom_field_mapper.key(field_name) || field_name.parameterize.underscore.to_sym
  end

  def emergency_contact_data?(field_name)
    ['emergency contact name', 'emergency contact number', 'emergency contact relationship'].include?(field_name)
  end

  def citizenship_data?(field_name)
    ['citizenship type', 'citizenship country'].include?(field_name)
  end

  def worker_document?(field_name)
    %w[upload_request paperwork_request].include?(field_name)
  end

  def field_options_mapper_service
    HrisIntegrationsService::Workday::FieldOptionMapper.new(company)
  end

  def get_doc_filename(document)
    "#{document.document_connection_relation.title} - #{user.first_name} #{user.last_name} (#{document.created_at.strftime('%d-%m-%Y')})"
  end

  def get_doc_category_wid
    workday_creds = company.get_integration('workday').integration_credentials
    doc_category_wid = workday_creds.by_name('Document Category WID').take&.value
    validate_presence!('Document Category WID', doc_category_wid)

    doc_category_wid
  end

  def worker_doc_data_hash(document_id, filename, file_path)
    { document_id: document_id, filename: filename, file_path: file_path, doc_category_wid: get_doc_category_wid }
  end

  def wid?(field_name)
    ['race/ethnicity', 'gender', 'federal marital status', 'emergency contact relationship',
     'military service', 't-shirt size', 'disability'].include?(field_name)
  end

end
