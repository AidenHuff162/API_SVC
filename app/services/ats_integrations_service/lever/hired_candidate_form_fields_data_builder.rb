class AtsIntegrationsService::Lever::HiredCandidateFormFieldsDataBuilder
  
  delegate :create, to: :logging_service, prefix: :log
  delegate :hired_candidate_form_fields_params_mapper, to: :params_mapper
  delegate :format_start_date, to: :helper_service

  def get_hired_candidate_form_fields(opportunity_id, api_key, company)
    begin
      forms = initialize_endpoint_service.lever_webhook_endpoint(opportunity_id, api_key, "/forms")
      form_data = fetch_hired_candidate_form_fields_data(forms)
      hired_candidate_form_fields_data = build_data(form_data)
      
      log_create(company, 'Lever', "Get Hired Candidate Form Fields Data-#{opportunity_id}", forms, 200, '/forms')
      hired_candidate_form_fields_data[:start_date] = format_start_date(company, hired_candidate_form_fields_data[:start_date], 'hired_candidate_form_fields')
      hired_candidate_form_fields_data
    rescue Exception => e
      log_create(company, 'Lever', "Get Hired Candidate Form Fields Data-#{opportunity_id}", {}, 500, '/forms', e.message)
      return nil
    end
  end

  def fetch_hired_candidate_form_fields_data(forms)
    form_fields = []
    if forms.present?
      forms['data'].try(:each) do |form|
        form_fields.concat(form['fields']) if form['fields'].present? && form['fields'].count > 1
      end
    end

    form_fields
  end

  def build_data(form_data)
    data = {}
    params_mapper = hired_candidate_form_fields_params_mapper()
    params_mapper.each do |key, value|
      data_value = nil
      data_value = form_data.try(:select) { |form_field| form_field["#{value[:identifier]}"].try(:downcase) == "#{value[:attribute]}" }&.first
      data.merge!("#{key}": data_value["#{value[:secondary_resource]}"]) if data_value.present?
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
