class AtsIntegrationsService::Lever::Helper
  
  delegate :create, to: :logging_service, prefix: :log

  def fetch_and_verify_webhook(lever_params, lever_api_instances)
    lever_api = nil
    lever_api_instances.each do |lever_instance|
      if verify_lever_webhook?(lever_params, lever_instance.signature_token)
        lever_api = lever_instance 
        break
      end
    end
    lever_api
  end

  def verify_lever_webhook?(lever_params, signature_token)
    return false if !signature_token.present?

    lever_token = lever_params['token'].to_s rescue nil
    lever_triggered_at = lever_params['triggeredAt'].to_s rescue nil
    lever_signature = lever_params['signature'].to_s rescue nil

    return false if !lever_token.present? || !lever_triggered_at.present? || !lever_signature.present?

    data = lever_token + lever_triggered_at
    digest = OpenSSL::Digest.new('sha256')
    generated_signature = OpenSSL::HMAC.hexdigest digest, signature_token, data
    generated_signature.to_s.eql?(lever_signature) if generated_signature.present?
  end

  def fetch_user_from_lever(opportunity_id, api_key, user_id, company, is_manager = false)
    return nil unless user_id.present?
    begin
      user = nil
      if api_key.present?
        lever_user = initialize_endpoint_service.lever_user_webhook_endpoint(user_id, api_key)

        log_create(company, 'Lever', "Get Lever User-#{opportunity_id}", lever_user, 200, "/user/#{user_id}")
        
        lever_user_data = lever_user["data"]

        if lever_user_data.present?
          if is_manager
            user = { email: lever_user_data["email"], name: lever_user_data["name"] } rescue nil
          else
            user = (lever_user_data["email"] || lever_user_data['name'])&.strip
          end
        end

        is_manager ? get_manger_from_company(company, user)&.id : user
      end
    rescue Exception => e
      log_create(company, 'Lever', "Get Lever User-#{opportunity_id}", {}, 500, "/user/#{user_id}", e.message)
    end
  end

  def get_manger_from_company(company, manager)
    return nil unless manager.present?
    PendingHire.get_employee_from_company(company, manager)
  end

  def format_start_date(company, start_date, section)
    return nil unless start_date.present?

    if section == 'hired_candidate_form_fields'
      DateTime.strptime(((start_date).to_f / 1000).to_s, '%s').to_date rescue nil
    elsif section == "candidate_data"
      DateTime.strptime(((start_date + ActiveSupport::TimeZone[company.time_zone].utc_offset).to_f / 1000).to_s, '%s').in_time_zone(company.time_zone).to_date rescue nil
    elsif section == "offer_data"
      DateTime.strptime((start_date / 1000).to_s, '%s').to_date rescue nil
    end
  end

  def valid_candidate_data(candidate_data)
    candidate_data.present? && candidate_data.values_at(:first_name, :last_name, :personal_email).all? { |v| v.present? }
  end

  def is_team_selected?(lever_integration)
    department_field = lever_integration.integration_field_mappings.find_by(integration_field_key: 'team_id')
    ['Team (Offer Form)', 'Team (Job Posting)'].include?(department_field.integration_selected_option['name']) rescue false
  end

  def logging_service
    LoggingService::WebhookLogging.new
  end

  def initialize_endpoint_service
    AtsIntegrationsService::Lever::Endpoint.new
  end
end
