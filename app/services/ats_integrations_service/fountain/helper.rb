class AtsIntegrationsService::Fountain::Helper
  delegate :update_partner, to: :endpoint_service
  delegate :create, to: :logging_service, prefix: :log

  def fountain_api(current_company, client_id, api_key)
    get_api(current_company, client_id, api_key)
  end

  def get_api(company, client_id, api_key)
    company.integration_instances.where(api_identifier: 'fountain')&.map { |i| i if i.api_key == api_key && i.client_id == client_id }[0]
  end

  def is_pending_hire_exists?(applicant_id, company)
    company.pending_hires.where(fountain_id: applicant_id).any?
  end

  def get_status_data(status)
    title = "Pending Hire#{status == 'completed' ? '' : ' not' } created in Sapling"
    {
      "applicant": {
        "partner_status": {
          "title": title,
          "status": status,
        }
      }
    }
  end

  def update_partner_status(applicant_id, company, status = 'completed')
    begin
      status_details = get_status_data(status)
      response = update_partner(applicant_id, status_details)
      if ['200', '201', '204'].include?(response.code)
        log_create(company, 'Fountain', 'Update partner status - Success', {data: status_details}.inspect, response.code, 'Update partner')
      else
        log_create(company, 'Fountain', 'Update partner status - Failure', {data: status_details}.inspect, response.code, 'Update partner')
      end
    rescue Exception => exception
      log_create(company, 'Fountain', 'Update partner status - Failure', {data: status_details}.inspect, 500, 'Update partner', exception.message)
    end
  end

  def authorize_webhook(client_id)
    decrypt_client_id = ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base).decrypt_and_verify(client_id)
    token = JsonWebToken.decode(decrypt_client_id)
    company_id = token["company_id"]
    company_domain = token["company_domain"]
    verify_company(company_id, company_domain)
  end

  def verify_company(company_id, company_domain)
    subdomain = company_domain.split('.', 2)[0]
    Company.find_by(id: company_id, subdomain: subdomain)
  end

  def is_verified?(params, fountain_signature)
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, ENV['FOUNTAIN_API_KEY'], params['fountain'].to_json)
    Rack::Utils.secure_compare(signature, fountain_signature)
  end

  def endpoint_service
    ::AtsIntegrationsService::Fountain::Endpoint.new
  end

  def logging_service
    LoggingService::WebhookLogging.new
  end
end
