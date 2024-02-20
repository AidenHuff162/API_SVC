class HrisIntegrationsService::AdpWorkforceNowU::UpdateCompanyCodesFromAdp
  attr_reader :company, :adp_wfn_api, :enviornment

  delegate :create_loggings, :fetch_adp_correlation_id_from_response, to: :helper
  delegate :fetch_company_codes, to: :events

  def initialize(adp_wfn_api)
    @adp_wfn_api = adp_wfn_api
    @company = adp_wfn_api&.company
    @enviornment = adp_wfn_api&.api_identifier&.split('_')&.last&.upcase
  end

  def sync
    configuration = HrisIntegrationsService::AdpWorkforceNowU::Configuration.new(adp_wfn_api)
    return unless configuration.adp_workforce_api_initialized? && enviornment.present? && ['US', 'CAN'].include?(enviornment) && adp_wfn_api.enable_company_code.present?

    begin
      access_token = configuration.retrieve_access_token
    rescue Exception => e
      log(500, 'UpdateSaplingFieldOptionsFromAdp - Access Token Retrieval - ERROR', { message: e.message })
      return
    end

    begin
      certificate = configuration.retrieve_certificate
    rescue Exception => e
      log(500, 'UpdateSaplingFieldOptionsFromAdp - Certificate Retrieval - ERROR', { message: e.message })
    end

    return unless access_token.present? && certificate.present?

    sync_company_codes(access_token, certificate)
  end

  private

  def sync_company_codes(access_token, certificate)
    begin
      response = fetch_company_codes(access_token, certificate)
      set_correlation_id(response)
      
      if response&.status == 200
        
        meta = JSON.parse(response&.body)
        sync_adp_company_codes(meta)

        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
        @adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api
      else
        log(response.status, "UpdateCompanyCodesFromAdp #{enviornment} - IntegrationMetadata - ERROR", { message: response.inspect })
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      log(500, "UpdateCompanyCodesFromAdp #{enviornment} - ERROR", { message: e.message })
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def sync_adp_company_codes(data)
    meta = data['meta']['/data/transforms'][0]['/jobOffer/offerAssignment/payrollGroupCode']['codeList']['listItems'] rescue []
    sync_custom_field_option_and_codes(meta, 'ADP Company Code') if meta.present?
  end

  def sync_custom_field_option_and_codes(data, field_name)
    return unless data.present? && field_name.present?
    data.each do |meta_data|
      CustomFieldOption.sync_adp_option_and_code(company, field_name, meta_data['codeValue'], meta_data['codeValue'], 
        enviornment)
    end
  end

  def helper
    HrisIntegrationsService::AdpWorkforceNowU::Helper.new
  end

  def events
    HrisIntegrationsService::AdpWorkforceNowU::Events.new
  end

  def set_correlation_id(response)
    @correlation_id = fetch_adp_correlation_id_from_response(response)
  end

  def log(status, action, result)
    create_loggings(company, "ADP Workforce Now - #{enviornment}", status, action, result.merge({adp_correlation_id: @correlation_id}))
  end
end
