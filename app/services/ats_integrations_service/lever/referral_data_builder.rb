class AtsIntegrationsService::Lever::ReferralDataBuilder
  
  delegate :create, to: :logging_service, prefix: :log

  def get_referral_data(opportunity_id, api_key, company)
    begin
      referral_data_response = initialize_endpoint_service.lever_webhook_endpoint(opportunity_id, api_key, '/referrals')
      
      referral_data = {}
      referral_data_field = referral_data_response['data'][0]['fields'][0] rescue {}
      if referral_data_field.present?
        referral_field = []
        referral_field.push({ "text" => "Referrer", "identifier" => "referrals", "value" => referral_data_field['value'] })
        referral_data.merge!(lever_custom_field: referral_field)
      end

      log_create(company, 'Lever', "Get Referral Data-#{opportunity_id}", referral_data_response, 200, '/referrals')
      referral_data
    rescue Exception => e
      log_create(company, 'Lever', "Get Referral Data-#{opportunity_id}", {}, 500, '/referrals', e.message)
      return nil
    end
  end

  def logging_service
    LoggingService::WebhookLogging.new
  end

  def initialize_endpoint_service
    AtsIntegrationsService::Lever::Endpoint.new
  end
end
