class HrisIntegrationsService::Workday::ParamsBuilder::Sapling < ApplicationService
  include HrisIntegrationsService::Workday::Exceptions
  attr_reader :company, :worker_data, :field_option_mapper, :personal_data, :helper_object, :org_type_for_dept

  delegate :convert_to_array, :custom_field_mapper, :user_cf_params_hash, :get_manager_from_org, to: :helper_object

  delegate :map_to_sapling_custom_field_option, :map_to_sapling_country, :map_to_sapling_state,
           :map_to_sapling_phone_format, :map_to_sapling_ld, :map_to_sapling_manager, to: :field_option_mapper


  def initialize(worker_data, company, helper_object)
    @company, @helper_object, @worker_data = company, helper_object, worker_data
    @field_option_mapper = HrisIntegrationsService::Workday::FieldOptionMapper.new(company)
    @org_type_for_dept = get_org_type_for_dept
  end

  def call
    return if worker_data.blank? || (@personal_data = worker_data[:personal_data]).blank?

    user_cf_params_hash(build_user_params.compact, build_custom_field_params.compact).compact
  end

  private

  def boolean_mapper
    { '1' => true, '0' => false }
  end

  def build_user_params
    user_params = {workday_id: worker_data[:worker_id]}
    build_name_params(user_params)
    build_email_params(user_params)
    build_employment_params(user_params)
    user_params[:image] = worker_data.dig(:photo_data, :image)
    build_worker_organization_data(user_params, convert_to_array(worker_data.dig(:organization_data, :worker_organization_data)))
    user_params
  end

  def build_name_params(user_params)
    %i[first_name last_name preferred_name].each { |field| user_params[field] = personal_data.dig(*worker_dig_hash[field]) }
  end

  def build_email_params(user_params)
    convert_to_array(personal_data.dig(:contact_data, :email_address_data)).each { |e| build_user_emails(user_params, e) }
  end

  def build_employment_params(user_params)
    return if (employment_data = worker_data[:employment_data]).blank?

    build_worker_job_data(user_params, convert_to_array(employment_data[:worker_job_data]).first)
    build_worker_status_data(user_params, employment_data[:worker_status_data])
  end

  def build_custom_field_params
    custom_field_params = {}
    info_data_hash = get_information_data_hash
    build_sapling_data_with_field_options(custom_field_params, info_data_hash)
    build_worker_name_data(custom_field_params)
    build_address_phone_data(custom_field_params, personal_data[:contact_data])
    build_employment_type(custom_field_params)
    build_private_data(custom_field_params, info_data_hash)
    build_emergency_contact_info(custom_field_params)
    build_organization_data(custom_field_params)
    custom_field_params
  end

  def build_worker_name_data(custom_field_params)
    custom_field_params[:middle_name] = personal_data.dig(*worker_dig_hash[:middle_name])
  end

  def build_worker_job_data(user_params, worker_job_data)
    return if worker_job_data.blank?

    user_params[:title] = worker_job_data.dig(*worker_dig_hash[:title])
    user_params[:workday_worker_subtype] = worker_job_data.dig(*worker_dig_hash[:workday_worker_subtype])[:id].second rescue nil
    user_params[:location_id] = map_to_sapling_ld(company.reload, :location, worker_job_data.dig(*worker_dig_hash[:location_id]))
    last_effective_manager_id = convert_to_array(worker_job_data.dig(*worker_dig_hash[:manager_id])).first.dig(:id).second rescue nil
    user_params[:manager_id] = map_to_sapling_manager(company, last_effective_manager_id)
  end

  def build_private_data(custom_field_params, information_data)
    custom_field_params[:national_id] = get_sapling_national_id(information_data[:national_id]&.dig(:national_id_data))
    custom_field_params[:date_of_birth] = information_data.dig(:information_data, :birth_date)
    custom_field_params[:nationality] = map_to_sapling_country(information_data.dig(:information_data, :primary_nationality_reference, :id)&.second)
  end

  def build_worker_status_data(user_params, worker_status_data)
    return if worker_status_data.blank?

    start_date = get_start_date(worker_status_data)
    user_params[:start_date] = start_date
    user_params[:state] = boolean_mapper[worker_status_data[:active]] || start_date.try(:>=, company.time.to_date) ? 'active' : 'inactive'
    user_params[:actual_start_date] = get_actual_start_date(worker_status_data)
    if boolean_mapper[worker_status_data[:terminated]] && (start_date.blank? || start_date < company.time.to_date)
      user_params[:last_day_worked] = worker_status_data[:termination_last_day_of_work] || worker_status_data[:termination_date]
      user_params[:termination_date] = worker_status_data[:termination_date]
      user_params[:termination_type] = boolean_mapper[worker_status_data[:termination_involuntary]] ? 'involuntary' : 'voluntary'
      user_params[:eligible_for_rehire] = worker_status_data[:eligible_for_hire_reference][:id].second.downcase rescue nil
    end
  end

  def build_worker_organization_data(user_params, worker_organization_data)
    worker_organization_data.each do |wod|
      next if (org_data = wod[:organization_data]).blank?

      org_type_ref = org_data.dig(:organization_type_reference, :id)&.second
      next unless org_type_for_dept == org_type_ref # example types: Supervisory, Cost_Center_Hierarchy

      user_params[:manager_id] ||= map_to_sapling_manager(company, get_manager_from_org(worker_organization_data))
      user_params[:team_id] = map_to_sapling_ld(company, :department, org_data[:organization_name])
    end
  end

  def get_org_role_data(org_role_data)
    convert_to_array(org_role_data).first
  end

  def worker_dig_hash
    {
      first_name: %i[name_data legal_name_data name_detail_data first_name],
      last_name: %i[name_data legal_name_data name_detail_data last_name],
      middle_name: %i[name_data legal_name_data name_detail_data middle_name],
      preferred_name: %i[name_data preferred_name_data name_detail_data first_name],
      title: %i[position_data business_title],
      workday_worker_subtype: %i[position_data worker_type_reference],
      location_id: %i[position_data business_site_summary_data name],
      manager_id: %i[position_data manager_as_of_last_detected_manager_change_reference]
    }
  end

  def build_sapling_data_with_field_options(custom_field_params, information_data_hash)
    {
      gender: { dig_from: :country_data, dig_attrs: %i[gender_reference id] },
      marital_status: { dig_from: :country_data, dig_attrs: %i[marital_status_reference id] },
      ethnicity: { dig_from: :country_data, dig_attrs: %i[ethnicity_reference id] },
      disability: { dig_from: :country_data, dig_attrs: %i[disability_status_data disability_reference id] },
      military_service: { dig_from: :information_data, dig_attrs: %i[military_service_data status_reference id] }
    }.each do |key, value|
      custom_field_params[key] = sapling_custom_field_mapper(key, information_data_hash[value[:dig_from]], value[:dig_attrs])
    end
    set_citizenship_data(custom_field_params, information_data_hash[:information_data])
  end

  def get_information_data_hash
    personal_information_data = convert_to_array(personal_data[:personal_information_data]).first
    {
      personal: personal_data,
      information_data: personal_information_data,
      national_id: convert_to_array(personal_data.dig(:identification_data, :national_id)).first,
      country_data: get_country_info_data(personal_information_data)
    }
  end

  def set_citizenship_data(custom_field_params, data)
    return unless data && (wids = convert_to_array(data[:citizenship_status_reference]).map { |wid| wid[:id]&.first }.compact).present?

    wids.map do |wid|
      field_name = company.custom_fields.joins(:custom_field_options).find_by('custom_field_options.workday_wid': wid)&.name
      custom_field_params[field_name.parameterize.underscore.to_sym] = map_to_sapling_custom_field_option(field_name, wid) if field_name.present?
    end
  end

  def get_country_info_data(personal_information_data)
    personal_info_for_country = convert_to_array(personal_information_data&.dig(:personal_information_for_country_data)).first
    convert_to_array(personal_info_for_country&.dig(:country_personal_information_data)).first
  end

  def build_address_phone_data(custom_field_params, contact_data)
    return if contact_data.blank?

    convert_to_array(contact_data[:address_data]).each { |ad| set_home_addresses(custom_field_params, ad) }
    convert_to_array(contact_data[:phone_data]).each { |pd| set_phone_number(custom_field_params, pd) }
  end

  def build_employment_type(custom_field_params)
    return if (worker_job_data = convert_to_array(worker_data.dig(:employment_data, :worker_job_data)).first).blank?

    # Employee_type in Workday is employment_status in sapling, doing sworker_job_datao for ctus creation
    custom_field_params[:employment_status] = worker_job_data.dig(:position_data, :position_time_type_reference, :id).second.humanize.titleize rescue nil
  end

  def organization_type_mapping(org_type)
    {
      Company: :company_entity,
      'ORGANIZATION_TYPE-3-38': :vertical
    }[org_type.to_sym] || org_type.downcase.to_sym
  end

  def valid_org_types?(org_type)
    %w[Company Cost_Center ORGANIZATION_TYPE-3-38].include?(org_type) # .push('Sub_Division', 'Division')
  end

  def get_organization_value(type, organization_data)
    "#{type == 'Cost_Center' ? "#{organization_data[:organization_reference_id]} - " : ''}#{organization_data[:organization_name]}"
  end

  def build_organization_data(custom_field_params)
    convert_to_array(worker_data.dig(:organization_data, :worker_organization_data)).each do |wod|
      organization_data = wod[:organization_data]
      organization_type_ref = organization_data.dig(:organization_type_reference, :id).try(:[], 1)
      next unless valid_org_types?(organization_type_ref)

      custom_field_params[organization_type_mapping(organization_type_ref)] = get_organization_value(organization_type_ref, organization_data)
    end
  end

  def build_user_emails(user_params, email_address_data)
    return if email_address_data.blank?

    address_hash = {HOME: :personal_email, WORK: :email}
    address_type = get_usage_type_data(email_address_data) rescue nil
    user_params[address_hash[address_type.to_sym]] = email_address_data[:email_address]
  end

  def get_usage_type_data(contact_data)
    type_data = convert_to_array(convert_to_array(contact_data[:usage_data]).first&.dig(:type_data)).first
    type_data.dig(:type_reference, :id).second
  end

  def set_home_addresses(custom_field_params, address_data)
    return unless address_data.present? && get_usage_type_data(address_data).downcase == 'home' rescue nil
    field_name = get_address_field_name(address_data)

    line_data = address_data[:address_line_data]
    country_data = address_data.dig(:country_reference, :id).try(:[], 1)
    state = map_to_sapling_state(country_data, address_data.dig(:country_region_reference, :id).try(:[], 2))
    custom_field_params[field_name] = {
      city: address_data[:municipality],
      zip: address_data[:postal_code],
      country: map_to_sapling_country(country_data),
      state: state
    }
    set_home_address_lines(custom_field_params[field_name], line_data)
  end

  def get_address_field_name(address_data)
    uses_for = convert_to_array(convert_to_array(address_data[:usage_data]).first&.dig(:use_for_reference))
    use_for_present?(uses_for, 'shipping') ? :shipping_address : :home_address
  end

  def use_for_present?(uses_for, key) # shipping mailing permanent
    uses_for.map { |use_for| use_for[:id].second&.downcase }.include?(key) # use_for might be null
  end

  def set_phone_number(custom_field_params, phone_data)
    return if phone_data.blank?

    phone_type_hash = { Landline: :home_phone_number, Mobile: :mobile_phone_number }
    phone_type = phone_data.dig(:phone_device_type_reference, :id).try(:[], 1)
    custom_field_params[phone_type_hash[phone_type.to_sym]] = get_phone_number(phone_type_hash[phone_type.to_sym], phone_data)
  end

  def get_phone_number(name, phone_data)
    type = company.get_field_type_by_name(name)
    number = phone_data[:'@wd:international_formatted_phone']
    type == 'phone' ? map_to_sapling_phone_format(number) : number.gsub(' ', '')
  end

  def build_emergency_contact_info(custom_field_params)
    convert_to_array(worker_data.dig(:related_person_data, :related_person)).each do |rp|
      next if rp.blank?

      emergency_contact_ref = rp.dig(:emergency_contact, :emergency_contact_data, :emergency_contact_priority_reference, :id)&.first
      next unless emergency_contact_ref[0]&.downcase == 'primary'

      emergency_name = rp.dig(:personal_data, :name_data, :legal_name_data, :name_detail_data, :'@wd:formatted_name')
      emergency_relation = sapling_custom_field_mapper(custom_field_mapper(:emergency_contact_relationship).titleize, rp, %i[related_person_relationship_reference id])
      emergency_num = rp.dig(:personal_data, :contact_data, :phone_data)

      custom_field_params[:emergency_contact_name] = emergency_name
      custom_field_params[:emergency_contact_relationship] = emergency_relation
      custom_field_params[:emergency_contact_number] = get_phone_number(:emergency_contact_number, emergency_num)
    end
  end

  def sapling_custom_field_mapper(key, data, attrs)
    map_to_sapling_custom_field_option(custom_field_mapper(key).titleize, get_wid_custom_field_value(data, attrs))
  end

  def get_wid_custom_field_value(data, attrs)
    # e.g, attrs: [ethnicity_reference id], in attrs, last index must be :id while first is the key of data which can be array
    data&.dig(attrs.first).is_a?(Array) ? data[attrs.first].first[attrs.last] : data&.dig(*attrs)
  end

  def get_start_date(worker_status_data)
    start_date = worker_status_data[:hire_date]
    %i[first_day_of_work original_hire_date continuous_service_date].each do |field|
      start_date = worker_status_data[field] if start_date.blank? || worker_status_data[field].try(:>, start_date)
    end
    start_date
  end

  def get_actual_start_date(worker_status_data)
    actual_start_date = worker_status_data[:hire_date]
    if actual_start_date.blank? || worker_status_data[:original_hire_date].try(:>, actual_start_date)
      actual_start_date = worker_status_data[:original_hire_date]
    end
    actual_start_date
  end

  def set_home_address_lines(home_address, lines_data)
    if lines_data.is_a?(Array)
      line1, line2 = lines_data
      home_address.merge!({ line1: line1, line2: line2 })
    else
      home_address[:line1] = lines_data
    end
  end

  def get_sapling_national_id(national_id_data)
    return if national_id_data.blank?

    id_country_ref, id_type_ref = %i[country_reference id_type_reference].map { |ref| national_id_data.dig(ref, :id) || [] }
    { id_country: id_country_ref.third, id_type: id_type_ref.second, id_number: national_id_data[:id] }
  end

  def get_org_type_for_dept
    credentials = company.get_integration('workday').integration_credentials
    org_type = credentials.by_name('Organization Type for Department').take&.value
    validate_presence!('Organization Type for Department', org_type)
    org_type.squish.titleize.gsub(' ', '_')
  end

end
