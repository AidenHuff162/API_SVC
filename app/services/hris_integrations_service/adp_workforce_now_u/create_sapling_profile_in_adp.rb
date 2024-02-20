class HrisIntegrationsService::AdpWorkforceNowU::CreateSaplingProfileInAdp
  attr_reader :company, :user, :adp_wfn_api, :enviornment, :params_builder_service, :data_builder_service

  delegate :create_loggings, :fetch_adp_correlation_id_from_response, :user_has_company_code?, :has_international_template?, :update_params, to: :helper_service

  def initialize(user, adp_wfn_api, enviornment)
    @user = user
    @company = user.company
    @adp_wfn_api = adp_wfn_api
    @enviornment = enviornment

    initialize_builders
  end

  def create
    configuration = HrisIntegrationsService::AdpWorkforceNowU::Configuration.new(adp_wfn_api)
    return unless configuration.adp_workforce_api_initialized? && enviornment.present? && ['US', 'CAN'].include?(enviornment)

    begin
      access_token = configuration.retrieve_access_token
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Create Profile in ADP - Access Token Retrieval - ERROR', { message: e.message, effected_profile: "#{user.full_name} (#{user.id})" })
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end

    return unless access_token.present?

    begin
      certificate = configuration.retrieve_certificate
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Create Profile in ADP - Certificate Retrieval - ERROR', { message: e.message, effected_profile: "#{user.full_name} (#{user.id})" })
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end

    return unless certificate.present?

    if (@user.adp_onboarding_template && (user_has_company_code?(@user) || has_international_template?(user))) || company.adp_v2_migration_feature_flag 
      applicant_onboard_v2(access_token, certificate) 
    else
      applicant_onboard_v1(access_token, certificate)
    end
  end

  def initialize_builders
    if company.domain.downcase == 'popsugar.saplingapp.io' && enviornment == 'US' 
      @params_builder_service = HrisIntegrationsService::AdpWorkforceNowU::PopSugar::ParamsBuilder.new
      @data_builder_service = HrisIntegrationsService::AdpWorkforceNowU::PopSugar::DataBuilder.new(enviornment)
    ################ #enabled V2 for warbyparker ###################
    # elsif company.domain.downcase == 'warbyparker.saplingapp.io' && enviornment == 'US' 
    #   @params_builder_service = HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::ParamsBuilder.new
    #   @data_builder_service = HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::DataBuilder.new(enviornment)
    ################################################################
    else
      @params_builder_service = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new
      @data_builder_service = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new(enviornment)
    end
  end

  private

  def applicant_onboard_v1(access_token, certificate)
    data = data_builder_service.build_applicant_onboard_data(user, adp_wfn_api, access_token, certificate, 'v1')
    params = params_builder_service.build_applicant_onboard_params(data)

    if company.can_push_adp_custom_fields? && company.domain == "databricks.saplingapp.io"
      params = HrisIntegrationsService::AdpWorkforceNow::Databricks::ManageAdpData.new(user).build_onboard_applicant_params(user, params)
    end

    message = nil

    begin
      response = events_service.applicant_onboard(params, access_token, certificate)
      set_correlation_id(response)

      begin #if json text error occurs then log and return
        result = JSON.parse(response&.body)
      rescue Exception => e
        message = 'Body Nil ADP WFN - V1'
        log_json_error(response.status, 'Create Profile in ADP V1 - Response Body Nil', { data: data, params: params, response: response.inspect, response_body: response&.body&.to_s, message: message }, params)
        return
      end

      if response&.status == 201
        adp_wfn_id = result['events'][0]['data']['output']['applicant']['associateOID'] rescue nil

        if adp_wfn_id.present?
          if enviornment == 'US'
            user.update_column(:adp_wfn_us_id, adp_wfn_id)
          elsif enviornment == 'CAN'
            user.update_column(:adp_wfn_can_id, adp_wfn_id)
          end
          @adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api
          log(response.status, 'Create Profile in ADP V1 - SUCCESS', { data: data, params: params, result: result }, params)
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
        else
          message = 'ADP ID not found.'
          log(response.status, 'Create Profile in ADP V1 - ERROR', { data: data, params: params, result: result, message: 'ADP ID not found.', effected_profile: "#{user.full_name} (#{user.id})" }, params)
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
        end
      else
        message = result['confirmMessage']['resourceMessages'][0]['processMessages'][0]['userMessage']['messageTxt'] rescue 'Error Occured in Profile Creation - V1'
        log(response.status, 'Create Profile in ADP V1 - ERROR', { data: data, params: params, result: result, message: message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      message = e.message
      log(500, 'Create Profile in ADP V1 - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def applicant_onboard_v2(access_token, certificate)
    data = data_builder_service.build_applicant_onboard_data(user, adp_wfn_api, access_token, certificate, 'v2')
    params = params_builder_service.build_v2_applicant_onboard_params(data, enviornment)

    if company.can_push_adp_custom_fields? && company.domain == "databricks.saplingapp.io"
      params = HrisIntegrationsService::AdpWorkforceNow::Databricks::ManageAdpData.new(user).build_onboard_applicant_params(user, params)
    end

    message = nil
    response = nil

    begin
      count = 0
      loop do
        response = events_service.applicant_onboard_v2(params, access_token, certificate)
        break if (response&.status == 201 || count == 5)
        update_params(response, params)
        count += 1
      end

      set_correlation_id(response)
      
      begin #if json text error occurs then log and return
        result = JSON.parse(response&.body)
      rescue Exception => e
        message = 'Body Nil ADP WFN - V2'
        log_json_error(response.status, 'Create Profile in ADP V2 - Response Body Nil', { data: data, params: params, response: response.inspect, response_body: response&.body&.to_s, message: message }, params)
        return
      end

      if response&.status == 201
        adp_wfn_id = result["_confirmMessage"]["messages"][1]["resourceID"] rescue nil

        if adp_wfn_id.present?
          if enviornment == 'US'
            user.update_column(:adp_wfn_us_id, adp_wfn_id)
          elsif enviornment == 'CAN'
            user.update_column(:adp_wfn_can_id, adp_wfn_id)
          end
          @adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api
          log(response.status, 'Create Profile in ADP V2 - SUCCESS', { data: data, params: params, result: result }, params)
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
        else
          message = 'ADP ID not found.'
          log(response.status, 'Create Profile in ADP V2 - ERROR', { data: data, params: params, result: result, message: 'ADP ID not found.', effected_profile: "#{user.full_name} (#{user.id})" }, params)
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
        end
      else
        message = result['_confirmMessage']['messages'][0]['messageText'] rescue 'Error Occured in Profile Creation - V2'
        log(response.status, 'Create Profile in ADP V2 - ERROR', { data: data, params: params, result: result, message: message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      message = e.message
      log(500, 'Create Profile in ADP V2 - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def log_json_error(code, action, result, params)
    log(code, action, result, params)
    ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
  end

  def helper_service; HrisIntegrationsService::AdpWorkforceNowU::Helper.new end
  def events_service; HrisIntegrationsService::AdpWorkforceNowU::Events.new end
  def set_correlation_id(response); @correlation_id = fetch_adp_correlation_id_from_response(response) end

  def log(status, action, result, request = nil)
    create_loggings(company, "ADP Workforce Now - #{enviornment}", status, action, result.merge({adp_correlation_id: @correlation_id}), request)
  end
end
