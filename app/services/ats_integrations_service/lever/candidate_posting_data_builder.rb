class AtsIntegrationsService::Lever::CandidatePostingDataBuilder
  
  delegate :candidate_posting_data_params_mapper, to: :params_mapper
  delegate :create, to: :logging_service, prefix: :log
  delegate :is_team_selected?, to: :helper_service

  def get_candidate_posting_data(opportunity_id, api_key, company, posting_id, integration)
    begin
      candidate_posting_resource_data = initialize_endpoint_service.lever_posting_webhook_endpoint(posting_id, api_key)
      candidate_posting_data = candidate_posting_resource_data['data'] rescue nil

      candidate_posting_data = build_data(candidate_posting_data, integration)
      log_create(company, 'Lever', "Get Candidate Posting Data-#{opportunity_id}", candidate_posting_resource_data, 200, "/postings/#{posting_id}")
      candidate_posting_data
    rescue Exception => e
      log_create(company, 'Lever', "Get Candidate Posting Data-#{opportunity_id}", {} , 500, "/postings/#{posting_id}", e.message)
      return nil
    end
  end

  def build_data(candidate_posting_data, integration)
    data = {}
    
    team_identifier = is_team_selected?(integration) ? 'team' : 'department' 

    params_mapper = candidate_posting_data_params_mapper({team_identifier: team_identifier})
    params_mapper.each do |key, value|
      data_value = nil
      data_value = candidate_posting_data["#{value[:attribute]}"]
      if data_value.present?
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
