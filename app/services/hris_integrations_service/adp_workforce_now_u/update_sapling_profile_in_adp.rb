class HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingProfileInAdp
  attr_reader :company, :user, :adp_wfn_api, :enviornment, :params_builder_service, :data_builder_service

  delegate :create_loggings, :fetch_adp_manager_position_id, :fetch_adp_correlation_id_from_response, to: :helper_service

  def initialize(user, adp_wfn_api, enviornment)
    @user = user
    @company = user.company
    @adp_wfn_api = adp_wfn_api
    @enviornment = enviornment

    initialize_builders
  end

  def update(field_name, value = nil, field_id = nil)
    return unless field_name.present?

    configuration = HrisIntegrationsService::AdpWorkforceNowU::Configuration.new(adp_wfn_api)
    return unless configuration.adp_workforce_api_initialized? && enviornment.present? && ['US', 'CAN'].include?(enviornment)

    begin
      access_token = configuration.retrieve_access_token
    rescue Exception => e
      log(500, 'Update Profile in ADP - Access Token Retrieval - ERROR', { message: e.message, effected_profile: "#{user.full_name} (#{user.id})" })
    end

    return unless access_token.present?

    begin
      certificate = configuration.retrieve_certificate
    rescue Exception => e
      log(500, 'Update Profile in ADP - Certificate Retrieval - ERROR', { message: e.message, effected_profile: "#{user.full_name} (#{user.id})" })
    end

    return unless certificate.present?

    field_name = field_name.downcase
    case field_name
    when 'personal email'
      change_personal_communication_email(value, access_token, certificate)
    when 'email'
      change_business_communication_email(value, access_token, certificate)
    when 'middle name'
      change_middle_name(value, access_token, certificate)
    when 'preferred name'
      change_preferred_name(value, access_token, certificate)
    when 'federal marital status'
      change_marital_status(access_token, certificate)
    when 'home address'
      change_legal_address(access_token, certificate)
    when 'home phone number'
      change_personal_communication_landline(access_token, certificate)
    when 'mobile phone number'
      change_personal_communication_mobile(access_token, certificate)
    when 'pay rate', 'rate type'
      change_base_remunration(access_token, certificate)
    when 'race id method', 'race/ethnicity'
      change_ethnicity(access_token, certificate)
    when 'manager id'
      change_manager(access_token, certificate)
    when 'termination date'
      terminate_employee(value, access_token, certificate)
    when 'is rehired'
      rehire_employee(access_token, certificate)
    else
      if field_id.present? && company.can_push_adp_custom_fields? && company.domain == "databricks.saplingapp.io" && enviornment == 'US'
        manage_databricks_custom_fields(user, field_id, certificate, access_token)
      elsif company.domain.downcase == 'popsugar.saplingapp.io' && enviornment == 'US'
        manage_popsugar_custom_fields(field_name, field_id, value, certificate, access_token)
      elsif company.domain.downcase == 'warbyparker.saplingapp.io' && enviornment == 'US'
        manage_warbyparker_custom_fields(field_name, field_id, value, certificate, access_token)
      end
    end
    @adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api
  end

  def initialize_builders
    if company.domain.downcase == 'popsugar.saplingapp.io'
      @params_builder_service = HrisIntegrationsService::AdpWorkforceNowU::PopSugar::ParamsBuilder.new
      @data_builder_service = HrisIntegrationsService::AdpWorkforceNowU::PopSugar::DataBuilder.new(enviornment)
    elsif company.domain.downcase == 'warbyparker.saplingapp.io'
      @params_builder_service = HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::ParamsBuilder.new
      @data_builder_service = HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::DataBuilder.new(enviornment)
    else
      @params_builder_service = HrisIntegrationsService::AdpWorkforceNowU::ParamsBuilder.new
      @data_builder_service = HrisIntegrationsService::AdpWorkforceNowU::DataBuilder.new(enviornment)
    end
  end

  private

  def change_personal_communication_email(value, access_token, certificate)
    data = data_builder_service.build_change_personal_communication_email_data(value, user)
    params = params_builder_service.build_change_personal_communication_email_params(data)

    begin
      response = events_service.change_personal_communication_email(params, access_token, certificate)
      set_correlation_id(response)

      log(response.status, 'Update Profile in ADP - Personal Email', { data: data, params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in ADP - Personal Email - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_business_communication_email(value, access_token, certificate)
    data = data_builder_service.build_change_business_communication_email_data(value, user)
    params = params_builder_service.build_change_business_communication_email_params(data)

    begin
      response = events_service.change_business_communication_email(params, access_token, certificate)
      set_correlation_id(response)

      log(response.status, 'Update Profile in ADP - Email', { data: data, params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in ADP - Email - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_middle_name(value, access_token, certificate)
    data = data_builder_service.build_change_middle_name_data(value, user)
    params = params_builder_service.build_change_middle_name_params(data)

    begin
      response = events_service.change_middle_name(params, access_token, certificate)
      set_correlation_id(response)

      log(response.status, 'Update Profile in ADP - Middle Name', { data: data, params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in ADP - Middle Name - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_preferred_name(value, access_token, certificate)
    data = data_builder_service.build_change_preferred_name_data(value, user)
    params = params_builder_service.build_change_preferred_name_params(data)

    begin
      response = events_service.change_preferred_name(params, access_token, certificate)
      set_correlation_id(response)

      log(response.status, 'Update Profile in ADP - Preferred Name', { data: data, params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in ADP - Preferred Name - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_marital_status(access_token, certificate)
    data = data_builder_service.build_change_marital_status_data(user)
    params = params_builder_service.build_change_marital_status_params(data)

    begin
      response = events_service.change_marital_status(params, access_token, certificate)
      set_correlation_id(response)

      log(response.status, 'Update Profile in ADP - Marital Status', { data: data, params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in ADP - Marital Status - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_legal_address(access_token, certificate)
    data = data_builder_service.build_change_legal_address_data(user)
    params = params_builder_service.build_change_legal_address_params(data)

    begin
      response = events_service.change_legal_address(params, access_token, certificate)
      set_correlation_id(response)

      log(response.status, 'Update Profile in ADP - Home Address', { data: data, params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in ADP - Home Address - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_personal_communication_landline(access_token, certificate)
    data = data_builder_service.build_change_personal_communication_landline_data(user)
    params = params_builder_service.build_change_personal_communication_landline_params(data)

    begin
      response = events_service.change_personal_communication_landline(params, access_token, certificate)
      set_correlation_id(response)

      log(response.status, 'Update Profile in ADP - Home Phone', { data: data, params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in ADP - Home Phone - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_personal_communication_mobile(access_token, certificate)
    data = data_builder_service.build_change_personal_communication_mobile_data(user)
    params = params_builder_service.build_change_personal_communication_mobile_params(data)

    begin
      response = events_service.change_personal_communication_mobile(params, access_token, certificate)
      set_correlation_id(response)

      log(response.status, 'Update Profile in ADP - Mobile Phone', { data: data, params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in ADP - Mobile Phone - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_base_remunration(access_token, certificate)
    data = data_builder_service.build_change_base_remunration_data(user)
    params = params_builder_service.build_change_base_remunration_params(data)
    return unless params

    begin
      response = events_service.change_base_remunration(params, access_token, certificate)
      set_correlation_id(response)

      log(response.status, 'Update Profile in ADP - Payroll Information', { data: data, params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in ADP - Payroll Information - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_ethnicity(access_token, certificate)
    data = data_builder_service.build_change_ethnicity_data(user)
    params = params_builder_service.build_change_ethnicity_params(data)
    
    return unless data[:ethnicity].present?

    begin
      response = events_service.change_race(params, access_token, certificate)
      set_correlation_id(response)

      log(response.status, 'Update Profile in ADP - Race/Ethnicity - SUCCESS', { data: data, params: params, response: JSON.parse(response.body) }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    rescue Exception => e
      log(500, 'Update Profile in ADP - Race/Ethnicity - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def change_manager(access_token, certificate)
    begin
      return unless user.reload.manager.present?
      manager_id = fetch_adp_manager_position_id(user.company, user.manager, enviornment, access_token, certificate)

      return unless manager_id.present?

      data = data_builder_service.build_change_manager_data(user, manager_id)
      params = params_builder_service.build_change_manager_params(data)

      response = events_service.change_manager(params, access_token, certificate)
      set_correlation_id(response)
     
      if response.status == 200
        log(response.status, 'Update Profile in ADP - Reports To - SUCCESS', { data: data, params: params, response: JSON.parse(response.body) }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
      else
        log(response.status, 'Update Profile in ADP - Reports To - ERROR', { data: data, params: params, response: JSON.parse(response.body), effected_profile: "#{user.full_name} (#{user.id})" }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      log(500, 'Update Profile in ADP - Reports To - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def terminate_employee(value, access_token, certificate)
    begin
      user.reload
      value = JSON.parse(value)
      value = value.map {|k, v| [k.to_sym, v] }.to_h
      data = data_builder_service.build_terminate_employee_data(value)
      position_id = fetch_adp_manager_position_id(user.company, user, enviornment, access_token, certificate)
      params = params_builder_service.build_terminate_employee_params(position_id, data)

      response = events_service.terminate_employee(params, access_token, certificate)
      set_correlation_id(response)

      if response.status == 200
        log(response.status, 'Terminate employee in ADP - SUCCESS', { data: data, params: params, response: JSON.parse(response.body) }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
      else
        log(response.status, 'Terminate employee in ADP - ERROR', { data: data, params: params, response: JSON.parse(response.body), effected_profile: "#{user.full_name} (#{user.id})" }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      log(500, 'Terminate employee in ADP - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def rehire_employee(access_token, certificate)
    begin
      user.reload
      position_id = fetch_adp_manager_position_id(user.company, user, enviornment, access_token, certificate)
      return unless position_id.present?

      data = data_builder_service.build_rehire_employee_data(user, position_id)
      params = params_builder_service.build_rehire_employee_params(data)

      response = events_service.rehire_employee(params, access_token, certificate)
      set_correlation_id(response)

      if [201, 200].include?(response.status)
        log(response.status, 'ReHire employee in ADP - SUCCESS', { data: data, params: params, response: JSON.parse(response.body) }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
      else
        log(response.status, 'ReHire employee in ADP - ERROR', { data: data, params: params, response: JSON.parse(response.body), effected_profile: "#{user.full_name} (#{user.id})" }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      log(500, 'ReHire employee in ADP - ERROR', { data: data, params: params, message: e.message, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def manage_databricks_custom_fields(user, field_id, certificate, access_token)
    ::HrisIntegrationsService::AdpWorkforceNow::Databricks::ManageAdpData.new(user, certificate, access_token).update_adp_from_sapling(field_id)
  end

  def manage_popsugar_custom_fields(field_name, field_id, field_value, certificate, access_token)
     HrisIntegrationsService::AdpWorkforceNowU::PopSugar::ManageCustomField.new(company, user, adp_wfn_api, enviornment,params_builder_service, data_builder_service, certificate, access_token).update_adp_from_sapling(field_name, field_id, field_value)
  end

  def helper_service
    HrisIntegrationsService::AdpWorkforceNowU::Helper.new
  end

  def events_service
    HrisIntegrationsService::AdpWorkforceNowU::Events.new
  end

  def set_correlation_id(response)
    @correlation_id = fetch_adp_correlation_id_from_response(response)
  end

  def log(status, action, result, request = nil)
    create_loggings(company, "ADP Workforce Now - #{enviornment}", status, action, result.merge({adp_correlation_id: @correlation_id}), request)
  end

  def manage_warbyparker_custom_fields(field_name, field_id, field_value, certificate, access_token)
    HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::ManageCustomField.new(company, user, adp_wfn_api, enviornment,params_builder_service, data_builder_service, certificate, access_token).update_adp_from_sapling(field_name, field_id, field_value)
  end
end
