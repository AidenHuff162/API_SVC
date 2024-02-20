class HrisIntegrationsService::Paylocity::UpdateSaplingProfileInPaylocity

  attr_reader :company, :user, :integration, :data_builder, :params_builder, :sapling_keys, :attributes

  delegate :create_loggings, :log_statistics, :notify_slack, :send_notifications, to: :helper_service

  def initialize(company, user, integration, data_builder, params_builder, attributes)
    @company = company
    @user = user
    @integration = integration

    @data_builder = data_builder
    @params_builder = params_builder
    @attributes = attributes
    @sapling_keys = Integration.paylocity
  end

  def perform
    update
  end

  private
  
  def update
    begin
      request_data = @data_builder.build_update_profile_data(attributes)
      request_params = @params_builder.build_update_profile_params(request_data)
      return unless request_params.present?
      
      options = configuration.generate_options(request_params, sapling_keys.signature_token, sapling_keys.client_id, sapling_keys.secret_token)
      resp = event_service.update(options)

      if !resp.success?
        create_loggings(@company, "Update User on Web Pay (#{user.id})", 500, request_params, {error: resp, response: resp.parsed_response.to_json, detail: resp.response.to_json})
        message = "*#{user.company.name}* tried to create a new profile but there was an issue sending *#{user.full_name}*'s information to *Paylocity*. We received... *#{resp.response.to_s}*"
        notify_slack(message)
        log_statistics('failed', @company)
      else
        user.update_column(:paylocity_onboard, true)
        send_notifications(user)
        create_loggings(user.company, "Update User on Web Pay (#{user.id})", 200, request_params, {success: resp, detail: resp.response.to_json})
        log_statistics('succcess', @company)
      end
    rescue Exception => e
      create_loggings(@company, "Update User on Web Pay (#{user.id})", 500, user.id.to_s, e.message, )
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
    HrisIntegrationsService::Paylocity::Eventsv1.new
  end
end