class HrisIntegrationsService::Paylocity::CreateSaplingProfileInPaylocity

  attr_reader :company, :user, :integration, :data_builder, :params_builder, :sapling_keys

  delegate :create_loggings, :log_statistics, :notify_slack, :send_notifications, to: :helper_service

  def initialize(company, user, integration, data_builder, params_builder)
    @company = company
    @user = user
    @integration = integration

    @data_builder = data_builder
    @params_builder = params_builder
    @sapling_keys = Integration.paylocity
  end

  def perform
    create
  end

  private
  
  def create
    begin
      resp, params = onboard
      if !resp.success?
        create_loggings(@company, "Create Profile in Paylocity Error - #{@user.id}", 500, params, {error: resp, message: resp.parsed_response.to_json, detail: resp.response.to_json, effected_profile: "#{@user.full_name} (#{@user.id})"})
        message = "*#{user.company.name}* tried to create a new profile but there was an issue sending *#{user.full_name}*'s information to *Paylocity*. We received... *#{resp.response.to_s}*"
        notify_slack(message)
        log_statistics('failed', @company)
      else
        user.update_column(:paylocity_onboard, true)
        send_notifications(user)
        create_loggings(@company, "Create Profile in Paylocity Success - #{@user.id}", 200, params, {success: resp, message: resp.parsed_response.to_json, detail: resp.response.to_json, effected_profile: "#{@user.full_name} (#{@user.id})"})
        log_statistics('succcess', @company)
      end
    rescue Exception => e
      create_loggings(@company, "Create Profile in Paylocity Error - #{@user.id}", 500, params, {error: resp, message: e.message, effected_profile: "#{@user.full_name} (#{@user.id})"})
      log_statistics('failed', @company)
    end
  end

  def helper_service
    ::HrisIntegrationsService::Paylocity::Helper.new
  end

  def configuration 
    HrisIntegrationsService::Paylocity::Configuration.new
  end

  def event_service
    if ['onboarding_webpay', 'onboarding_only', 'one_way_onboarding_webpay'].include?(integration.integration_type) 
      HrisIntegrationsService::Paylocity::Eventsv1.new
    else
      HrisIntegrationsService::Paylocity::Eventsv2.new 
    end
  end

  def onboard(add_company_sui_state=false, is_retry=false)
    request_data = @data_builder.build_create_profile_data(add_company_sui_state)
    request_params = @params_builder.build_create_profile_params(request_data)
    return unless request_params.present?
    
    options = configuration.generate_options(request_params, sapling_keys.signature_token, sapling_keys.client_id, sapling_keys.secret_token)
    resp = event_service.request_onboard(integration.company_code, options)

    if !resp.success?
      if resp.response.to_s.include?("suiState must be one of the following") && !is_retry
        onboard(true, true)
      end
    end

    return resp, request_params
  end
end