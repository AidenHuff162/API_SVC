class AtsIntegrationsService::JazzHr
  require 'openssl'

  attr_reader :request, :payload, :jazz_integration

  def initialize(request, payload)
    @request = request
    @payload = payload

    @jazz_integration = initialize_associated_integration
  end

  def manage_pending_hire
    create_or_update_pending_hire
  end

  def fetch_company
    jazz_integration.company
  end

  private

  def initialize_associated_integration
    integrations = fetch_jazz_integrations
    response_data = { data: payload.to_json }

    begin
      integrations.each do |integration|
        return integration if verify_integration_credentials?(integration)
      end
    rescue Exception => e
      response_data[:error] = e.message
    end

    create_webhook_logging(nil, 'JazzHR', 'Authentication', payload, 'failed', 'Service::JazzHR/initialize_associated_integration', response_data[:error])

    raise CanCan::AccessDenied
  end

  def fetch_jazz_integrations
    IntegrationInstance.where(api_identifier: 'jazz_hr')
  end
  #:nocov:
  def verify_integration_credentials?(integration)
    verify_client_id?(integration) && verify_client_secret?(integration)
  end

  def verify_client_id?(integration)
    payload['client_id'] == request.headers['QUERY_STRING'].split('=')[1] && integration.client_id == payload['client_id']
  end

  def verify_client_secret?(integration)
    return unless integration.client_secret.present?

    if request.headers['HTTP_X_JAZZHR_EVENT'] == 'CANDIDATE-EXPORT'
      data = payload['jazz'].to_json.gsub('null', '[]').gsub('/', '\/')
    else
      data = JSON.generate(payload['jazz'], {space: ' '})
    end
    client_secret = integration.client_secret

    digest = OpenSSL::Digest.new('sha256')
    generated_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), client_secret, data)

    request.headers['HTTP_X_JAZZHR_SIGNATURE'] == generated_signature
  end
  #:nocov:
  def create_or_update_pending_hire
    begin
      data = build_data

      fetch_company.pending_hires.find_or_initialize_by(jazz_hr_id: data[:jazz_hr_id]).update!(data)
      create_webhook_logging(fetch_company, 'JazzHR', 'Create', {data: data, payload: payload}, 'succeed', 'Service::JazzHr/create_or_update_pending_hire')
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(fetch_company)
      @jazz_integration.update_column(:synced_at, DateTime.now)
    rescue Exception => e
      create_webhook_logging(fetch_company, 'JazzHR', 'Create', {payload: payload}, 'failed', 'Service::JazzHr/create_or_update_pending_hire', e.message)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(fetch_company)
    end
  end

  def build_data
    candidate = payload['jazz']['candidate']
    person = candidate['person']

    data = {
      jazz_hr_id: person['id']['value'],
      first_name: person['name']['given'],
      last_name: person['name']['family']
    }

    communication = person['communication']

    # address = communication['address']&.first
    # if address.present?
    #   data[:custom_fields] = {}
    #   data[:custom_fields][:address_line_1] = address['line']
    #   data[:custom_fields][:city] = address['city']
    #   data[:custom_fields][:state] = address['countrySubdivisions'][0]['value'] rescue nil
    #   data[:custom_fields][:zip_code] =  address['postalCode']
    # end

    gender = person['gender']
    if gender.present?
      data[:custom_fields] = {}
      data[:custom_fields][:gender] = gender
    end

    phone = communication['phone']&.first
    if phone.present?
      data[:phone_number] = phone['formattedNumber']
    end

    email_address = communication['email']&.first
    if email_address.present?
      data[:personal_email] = email_address['address']
    end

    profile = candidate['profiles']&.first
    associatedPositionOpenings = profile['associatedPositionOpenings']&.first

    if associatedPositionOpenings.present?
      data[:title] = associatedPositionOpenings['positionTitle']
      candidateStatus = associatedPositionOpenings['candidateStatus'] || {}

      data[:employee_type] = candidateStatus['name']
      if candidateStatus['category'] && candidateStatus['category'] == 'Hired'
        data[:start_date] = candidateStatus['transitionDateTime']&.in_time_zone(fetch_company.time_zone)&.strftime("%m-%d-%Y").to_s
      end

      if data[:title].present?
        jobs_data = fetch_job_from_jazz(data[:title])

        if jobs_data.present?
          if jobs_data['country_id'].present? || jobs_data['city'].present?
            data[:location_id] = fetch_location(jobs_data['country_id']).try(:id) || fetch_location(jobs_data['city']).try(:id)
          end

          if jobs_data['department'].present?
            data[:team_id] = fetch_team(jobs_data['department']).try(:id) rescue nil
          end

          # if jobs_data['hiring_lead'].present?
          #   managers_data = fetch_manager_from_jazz(jobs_data['hiring_lead'])
          #   manager_email = managers_data['email'] rescue nil

          #   if manager_email.present?
          #     data[:manager_id] = fetch_company.users.where('email = ? OR personal_email = ?', manager_email, manager_email)&.take.try(:id)
          #   end
          # end
        end
      end
    end

    data
  end

  def fetch_job_from_jazz(position_title)
    begin
      response = HTTParty.get("https://api.resumatorapi.com/v1/jobs/title/#{position_title.gsub(' ', '%20')}?apikey=#{jazz_integration.api_key}")

      if response.ok?
        data = JSON.parse(response.body)
        create_webhook_logging(fetch_company, 'JazzHR', 'Fetch job', {status: response.code, data: data}, 'succeed', 'Service::JazzHr/fetch_job_from_jazz')
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(fetch_company)

        return (data.class == Array) ? data[0] : data
      else
        create_webhook_logging(fetch_company, 'JazzHR', 'Fetch job', {status: response.code}, 'failed', 'Service::JazzHr/fetch_job_from_jazz')
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(fetch_company)
      end
    rescue Exception => e
      create_webhook_logging(fetch_company, 'JazzHR', 'Fetch job', {}, 'failed', 'Service::JazzHr/fetch_job_from_jazz', e.message)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(fetch_company)
    end

    return nil
  end

  def fetch_manager_from_jazz(hiring_lead)
    begin
      response = HTTParty.get("https://api.resumatorapi.com/v1/users/#{hiring_lead}?apikey=#{jazz_integration.api_key}")

      if response.ok?
        data = JSON.parse(response.body)
        create_webhook_logging(fetch_company, 'JazzHR', 'Fetch manager', {status: response.code, data: data}, 'succeed', 'Service::JazzHr/fetch_manager_from_jazz')
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(fetch_company)
        return data
      else
        create_webhook_logging(fetch_company, 'JazzHR', 'Fetch manager', {status: response.code}, 'failed', 'Service::JazzHr/fetch_manager_from_jazz')
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(fetch_company)
      end
    rescue Exception => e
      create_webhook_logging(fetch_company, 'JazzHR', 'Fetch manager', {}, 'failed', 'Service::JazzHr/fetch_manager_from_jazz', e.message)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(fetch_company)
    end

    return nil
  end

  def fetch_location(name)
    return unless name.present?
    fetch_company.locations.where('name ILIKE ?', name).take
  end

  def fetch_team(name)
    return unless name.present?
    fetch_company.teams.where('name ILIKE ?', name).take
  end

  def create_webhook_logging company, integration, action, data, status, location, error=nil
    @webhook_logging ||= LoggingService::WebhookLogging.new
    @webhook_logging.create(company, integration, action, data, status, location, error)
  end
end
