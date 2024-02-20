class AtsIntegrationsService::LinkedIn
  require 'openssl'

  attr_reader :company, :linked_in_integration, :payload

  def initialize company, params, enabling=nil 
    @company = company
    @payload = params
    @linked_in_integration = fetch_linked_in_integrations if enabling.blank?
  end

  def manage_pending_hire
    create_or_update_pending_hire
  end

  def register_extension
    data = {'patch': {
                      '$set': {
                        'displayName': {
                          'localized': {
                            'en_US': "Sapling HR #{company.subdomain}"
                          }
                        },
                        'description': {
                          'localized': {
                            'en_US': 'A complete solution to HR.'
                          }
                        },
                        'onboardingUrl': 'https://rocketship.ngrok.io/linkedin-onboard',
                        'learnMoreUrl': 'https://www.kallidus.com/privacy-policy',
                        'callbackUrl': 'https://rocketship.ngrok.io/api/v1/webhook/linked_in/callback'
                      }
                    }
                  }
    post_request 'https://api.linkedin.com/v2/hireThirdPartyExtensionProviders/extensionType=HRIS&extensionProvider=THIRD_PARTY', data
  end

  def update_extension
    if payload[:enable].present? && payload[:hiring_context].present?
      enable_extension
    else
      disable_extension_on_linked_in payload[:hiring_context]
    end
  end

  def disable_extension hiring_context
    disable_extension_on_linked_in hiring_context
  end

  def validate_onboarding_signature
    begin 
      raise CanCan::AccessDenied unless validate_signature? 
    rescue Exception => e
      create_loggings(company, I18n.t('linked_in.api_name'), 500, I18n.t('linked_in.signature_failure'), {error: e})
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(company)
      
      raise CanCan::AccessDenied
    end
  end
  
  def validate_callback_signature request_signature
    begin 
      validate_call_back_signature? request_signature
    rescue Exception => e
      create_loggings(company, I18n.t('linked_in.api_name'), 500, I18n.t('linked_in.callback_signature_failure'), {error: e})
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(company)

      raise CanCan::AccessDenied
    end
  end

  private

  def enable_extension 
    integration = company.integration_instances.find_or_initialize_by(api_identifier: 'linked_in')
    if integration.present?
      integration.hiring_context(payload[:hiring_context])
      integration.save!
      update_extension_on_linked_in "ENABLED", payload[:hiring_context]
    end
  end
  
  def disable_extension_on_linked_in hiring_context
    update_extension_on_linked_in "PROVIDER_EXCEPTION", hiring_context
  end
  
  def fetch_linked_in_integrations
    begin
      integration = company.integration_instances.where(api_identifier: 'linked_in', state: :active).take
      raise ActiveRecord::RecordNotFound if integration.blank?
      return integration if integration.present?
    rescue Exception => e
      create_loggings(company, I18n.t('linked_in.api_name'), 500, I18n.t('linked_in.fetching_failure'), {error: e})
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(company)

      raise CanCan::AccessDenied
    end
  end

  def generate_access_token
    begin
      uri = URI('https://www.linkedin.com/oauth/v2/accessToken')
      res = Net::HTTP.post_form(uri, 'grant_type' => 'client_credentials', 'client_id' => ENV['LINKED_IN_CLIENT_ID'], 'client_secret' => ENV['LINKED_IN_CLIENT_SECRET']) 
      if res.message == 'OK'
        create_loggings(company, I18n.t('linked_in.api_name'), res.code, I18n.t('linked_in.generating_token_success'), JSON.parse(res.body))
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(company)
        return JSON.parse(res.body)["access_token"]
      else
        raise CanCan::AccessDenied
      end
    rescue Exception => e
      create_loggings(company, I18n.t('linked_in.api_name'), res.code, I18n.t('linked_in.generating_token_failure'), {data: JSON.parse(res.body), error: e})
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(company)
      return
    end
  end

  def create_or_update_pending_hire 
    response = fetch_user
    if response.message == 'OK'
      begin
        create_loggings(company, I18n.t('linked_in.api_name'), response.code, I18n.t('linked_in.fetched_user_success'), JSON.parse(response.body), payload.to_json)
        data = build_data(JSON.parse(response.body))
        company.pending_hires.find_or_initialize_by(personal_email: data[:personal_email]).update!(data)
        update_user_on_linked_in 
        create_loggings(company, I18n.t('linked_in.api_name'), 200, 'Creating Pending Hire - Success', data)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(company)
      rescue Exception => e
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(company)
        create_loggings(company, I18n.t('linked_in.api_name'), 500, 'Creating Pending Hire - Failure', {data: data, error: e})
      end
    else
      create_loggings(company, I18n.t('linked_in.api_name'), JSON.parse(response.body)['status'], I18n.t('linked_in.fetched_user_failure'), {requester_id: payload['hrisRequestId'], message: JSON.parse(response.body)['message']}, payload)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(company)
    end
  end

  def update_extension_on_linked_in status, hiring_context
    begin
      data = {"patch": {
                "$set": {
                  "status": "#{status}"
                }
              }
            }
      
      response = post_request "https://api.linkedin.com/v2/hireThirdPartyExtensions/hiringContext=#{hiring_context}&extensionType=HRIS&extensionProvider=THIRD_PARTY", data
      
      if response.message == "No Content"
        create_loggings(company, I18n.t('linked_in.api_name'), response.code, I18n.t('linked_in.enabling_success'), {result: response.message})
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(company)
      else
        create_loggings(company, I18n.t('linked_in.api_name'), JSON.parse(response.body)["status"], I18n.t('linked_in.enabling_failure'), {message: JSON.parse(response.body)["message"]})
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(company)
      end
    rescue Exception => e
      create_loggings(company, I18n.t('linked_in.api_name'), JSON.parse(response.body)["status"], I18n.t('linked_in.enabling_failure'), {error: e})
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(company)
    end
  end

  def build_data user
    data = {
      first_name: user['candidateProfile']['firstName'],
      last_name: user['candidateProfile']['lastName'],
    }

    data[:company_id] = company.id  
    data[:personal_email] = user['candidateProfile']['emailAddresses']&.first if user['candidateProfile']['emailAddresses'].present?
    data[:phone_number] = user['candidateProfile']['phoneNumbers']&.first['number'] if user['candidateProfile']['phoneNumbers'].present?
    data[:title] = user['jobTitle'].blank? ? nil : user['jobTitle']
    data[:location_id] = fetch_location(user['jobLocation']).try(:id) if user['jobLocation'].present?
    data[:start_date] = Date.new(user['startDate']['year'], user['startDate']['month'], user['startDate']['day'])&.in_time_zone(company.time_zone)&.strftime("%m-%d-%Y").to_s
    
    data
  end

  def fetch_user
    access_token = generate_access_token
    url = URI("https://api.linkedin.com/v2/hireThirdPartyHrisProfiles/hiringContext=#{linked_in_integration.hiring_context}&hrisRequestId=#{payload['hrisRequestId']}&extensionProvider=THIRD_PARTY")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl  = true

    request = Net::HTTP::Get.new(url)
    request['Authorization'] = "Bearer #{access_token}"
    http.request(request)
  end


  def update_user_on_linked_in
    data = {'patch': {
              '$set': {
              'status': 'COMPLETED'
              }
            }
          }
    response = post_request "https://api.linkedin.com/v2/hireThirdPartyHrisProfiles/hiringContext=#{linked_in_integration.hiring_context}&hrisRequestId=#{payload["hrisRequestId"]}&extensionProvider=THIRD_PARTY", data 
    if response.message == "No Content"
      create_loggings(company, I18n.t('linked_in.api_name'), response.code, I18n.t('linked_in.updating_user_success'), {requester_id: payload['hrisRequestId']}, payload)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(company)
    else
      create_loggings(company, I18n.t('linked_in.api_name'), JSON.parse(response.body)["status"], I18n.t('linked_in.updating_user_failure'), {requester_id: payload['hrisRequestId'], message: JSON.parse(response.body)['message']}, payload)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(company)
    end
  end

  def fetch_location(name)
    company.locations.where('name ILIKE ?', name).take
  end

  def create_loggings(company, integration_name, status, action, result, api_request = 'No Request')
    LoggingService::IntegrationLogging.new.create(@company, integration_name, action, api_request, result, status)
  end

  def post_request url, data
    access_token = generate_access_token
    url = URI(url)

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl  = true

    request = Net::HTTP::Post.new(url)
    request['Authorization'] = "Bearer #{access_token}" 
    request['x-restli-method'] = 'partial_update'
    request['content-type'] = 'text/plain'
    request.body = data.to_json
    http.request(request)
  end

  def validate_signature?
    return unless payload['extensionType'].present? && payload['hiringContext'].present? && payload['redirectUrl'].present? && payload['signature'].present?
    
    data ='hmacsha256='+{"hiringContext":"#{payload['hiringContext']}","extensionType":"#{payload['extensionType']}","redirectUrl":"#{payload['redirectUrl']}"}.to_json
    payload['signature'] == generate_signature(data)
  end

  def validate_call_back_signature? request_signature
    return unless payload['type'].present? && payload['type'] == 'CREATE_THIRD_PARTY_HRIS_EXPORT_PROFILE_REQUEST' && payload['hiringContext'].present? && payload['hrisRequestId'].present? && payload['expiresAt'].present? && request_signature.present?
    
    data = 'hmacsha256='+{"hiringContext":"#{payload['hiringContext']}","type":"#{payload['type']}","hrisRequestId":"#{payload['hrisRequestId']}","expiresAt":payload['expiresAt']}.to_json
    request_signature == generate_signature(data)
  end

  def generate_signature data
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), ENV['LINKED_IN_CLIENT_SECRET'], data)
  end
end