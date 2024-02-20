class AtsIntegrationsService::Lever::CandidateDataBuilder
  
  delegate :candidate_data_params_mapper, to: :params_mapper
  delegate :create, to: :logging_service, prefix: :log
  delegate :format_start_date, to: :helper_service

  def get_candidate_data(opportunity_id, api_key, company)
    begin
      candidate_data_response = initialize_endpoint_service.lever_webhook_endpoint(opportunity_id, api_key)
      candidate_data = build_data(candidate_data_response['data'])
      
      if candidate_data_response['data'] && candidate_data_response['data']['sources'] && (candidate_data_response['data']['sources'][0] == "Referral" || candidate_data_response['data']['sources'][0] == "Social referral")
        candidate_data.merge!(referral_data: true)
      end

      if candidate_data_response['data']['sources'].present? && candidate_data_response['data']['sources'].length > 0
        source_field = []
        source_field.push({ "text" => "Source", "identifier" => "sources", "value" => candidate_data_response['data']['sources'][0] })
        candidate_data.merge!({lever_custom_field: source_field})
      end

      log_create(company, 'Lever', "Get Candidate Data-#{opportunity_id}", candidate_data_response, 200, '/opportunities')
      candidate_data[:start_date] = format_start_date(company, candidate_data[:start_date], 'candidate_data')
      candidate_data
    rescue Exception => e
      log_create(company, 'Lever', "Get Candidate Data-#{opportunity_id}", {}, 500, '/opportunities', e.message)
      return nil
    end
  end

  def build_data(candidate_data)
    data = {}
    params_mapper = candidate_data_params_mapper()
    params_mapper.each do |key, value|
      data_value = nil
      data_value = candidate_data["#{value[:attribute]}"]
      if data_value.present?
        data_value = data_value.split(' ', 2)[value[:split_index]] if value[:is_split]
        data_value = data_value[0] if value[:in_array].present?
        data_value = data_value["#{value[:secondary_resource]}"] if value[:secondary_resource].present?
      end
      data.merge!("#{key}": data_value)
    end
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

  def helper_service
    AtsIntegrationsService::Lever::Helper.new
  end
end
