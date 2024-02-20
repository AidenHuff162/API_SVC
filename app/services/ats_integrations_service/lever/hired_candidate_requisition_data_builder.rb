class AtsIntegrationsService::Lever::HiredCandidateRequisitionDataBuilder
  
  delegate :hired_candidate_requisition_data_params_mapper, to: :params_mapper
  delegate :create, to: :logging_service, prefix: :log

  def get_hired_candidate_requisition_data(opportunity_id, api_key, company, requisition_id)
    begin
      hired_candidate_requisition = initialize_endpoint_service.lever_requisitions_webhook_endpoint(requisition_id, api_key)
      return nil unless hired_candidate_requisition['data'].present?
      
      is_customFields_present = hired_candidate_requisition['data']['customFields'].present?
      hired_candidate_mapping = build_params_mapper(company, is_customFields_present)

      hired_candidate_requisition_data = build_data(hired_candidate_requisition['data'], hired_candidate_mapping)
      log_create(company, 'Lever', "Get Hired Candidate Requistion Data-#{opportunity_id}", hired_candidate_requisition, 200, "/requisitions/#{requisition_id}")
      hired_candidate_requisition_data
    rescue Exception => e
      log_create(company, 'Lever', "Get Hired Candidate Requistion Data-#{opportunity_id}", {}, 500, "/requisitions/#{requisition_id}", e.message)
      return nil
    end
  end

  def build_params_mapper(company, custom_data_present)
    params_mapper = hired_candidate_requisition_data_params_mapper()

    params_mapper.each do |key, mapper|
      field = company.prefrences["default_fields"].select { |f| f['name'] == "#{mapper[:attribute]}" }&.first
      mapper[:attribute] = field['lever_requisition_field_id']
      mapper[:is_lever_custom_field] = false if is_requisition_default_field?(field['lever_requisition_field_id'])
    end

    company.custom_fields.where.not(lever_requisition_field_id: nil).each do |custom_field|
      map_value = {is_lever_custom_field: true, is_sapling_custom_field: true}
      map_value.merge!(attribute: custom_field.lever_requisition_field_id)
      map_value[:is_lever_custom_field] = false if is_requisition_default_field?(custom_field.lever_requisition_field_id)
      map_value.merge!(name: custom_field.name)
      key = custom_field&.name&.downcase&.parameterize&.underscore

      if custom_field.lever_requisition_field_id == 'employmentStatus'
        params_mapper[:employee_type][:is_lever_custom_field] = map_value[:is_lever_custom_field]
        params_mapper[:employee_type][:attribute] = map_value[:attribute]
        params_mapper[:employee_type][:name] = map_value[:name]
      else
        params_mapper.merge!("#{key}": map_value)
      end
    end if custom_data_present
    params_mapper
  end

  def is_requisition_default_field?(lever_requisition_field_id)
    ["name", "requisitionCode", "internalNotes", "employmentStatus", "location", "team", "department", "hiringManager"].include?(lever_requisition_field_id)
  end

  def build_data(hired_candidate_requisition_data, params_mapper)
    data = {}
    custom_fields = []
    params_mapper.each do |key, value|
      data_value = nil
      if value[:is_lever_custom_field]
        data_value = hired_candidate_requisition_data["customFields"]["#{value[:attribute]}"] rescue nil
      else
        data_value = hired_candidate_requisition_data["#{value[:attribute]}"]
      end

      if data_value.present?
        custom_fields.push({ "text" => value[:name], "identifier" => "requisitions", "value" => data_value }) if value[:is_sapling_custom_field].present? || value[:is_sapling_custom_field] == 'both'
        data.merge!("#{key}": data_value) if !value[:is_sapling_custom_field].present? || value[:is_sapling_custom_field] == 'both'
      end
    end

    data[:lever_custom_field] = custom_fields if custom_fields.present?
    data
  end

  def initialize_endpoint_service
    AtsIntegrationsService::Lever::Endpoint.new
  end

  def params_mapper
    AtsIntegrationsService::Lever::ParamsMapper.new
  end

  def logging_service
    LoggingService::WebhookLogging.new
  end
end
