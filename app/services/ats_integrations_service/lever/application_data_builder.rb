class AtsIntegrationsService::Lever::ApplicationDataBuilder
  
  delegate :create, to: :logging_service, prefix: :log
  delegate :application_data_params_mapper, to: :params_mapper

  def get_application_data(opportunity_id, api_key, company)
    begin
      hired_archive_reason = get_hired_archive_reason(opportunity_id, api_key, company)

      applications = initialize_endpoint_service.lever_webhook_endpoint(opportunity_id, api_key, "/applications")
      application_data = build_application_data(applications, hired_archive_reason)
      
      log_create(company, 'Lever', "Get Application Data-#{opportunity_id}", applications, 200, '/applications')
      application_data
    rescue Exception => e
      log_create(company, 'Lever', "Get Application Data-#{opportunity_id}", {}, 500, '/applications', e.message)
      return nil
    end
  end

  def build_application_data(applications, hired_archive_reason)
    application_data = {}
    params_mapper = application_data_params_mapper()

    applications['data'].try(:each) do |application|
      application_archived_reason = application['archived']['reason'] rescue nil
      if application_archived_reason.present? && application_archived_reason.eql?(hired_archive_reason)

        params_mapper.each do |key, value|
          application_data.merge!("#{key}": application["#{value[:attribute]}"])
        end

        posting = application['posting'] rescue nil
        requisition_id = application['requisitionForHire']['id'] rescue nil
        application_data.merge!(posting: posting, requisition_id: requisition_id)
      end
    end
    application_data
  end

  def get_hired_archive_reason(opportunity_id, api_key, company)
    begin
      archive_reason = initialize_endpoint_service.lever_archived_webhook_endpoint("/archive_reasons?type=hired", api_key)
      
      log_create(company, 'Lever', "Get Hired Archived Reason Data-#{opportunity_id}", archive_reason, 200, '/archive_reasons?type=hired')
      archive_reason['data'][0]['id'] rescue nil
    rescue Exception => e
      log_create(company, 'Lever', "Get Hired Archived Reason Data-#{opportunity_id}", {}, 500, '/archive_reasons?type=hired', e.message)
    end
  end

  def initialize_endpoint_service
    AtsIntegrationsService::Lever::Endpoint.new
  end

  def logging_service
    LoggingService::WebhookLogging.new
  end

  def params_mapper
    AtsIntegrationsService::Lever::ParamsMapper.new
  end
end
