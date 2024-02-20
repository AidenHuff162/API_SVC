class HrisIntegrationsService::AdpWorkforceNowU::UpdateOnboardingTemplatesFromAdp
  attr_reader :company, :adp_wfn_api, :enviornment, :access_token, :certificate

  delegate :create_loggings, :fetch_adp_correlation_id_from_response, to: :helper
  delegate :fetch_onboarding_templates, :fetch_v2_onboarding_templates, to: :events

  def initialize(adp_wfn_api)
    @adp_wfn_api = adp_wfn_api
    @company = adp_wfn_api&.company
    @enviornment = adp_wfn_api&.api_identifier&.split('_')&.last&.upcase
  end

  def sync
    configuration = HrisIntegrationsService::AdpWorkforceNowU::Configuration.new(adp_wfn_api)
    return unless configuration.adp_workforce_api_initialized? && enviornment.present? && ['US', 'CAN'].include?(enviornment)
    begin
      @access_token = configuration.retrieve_access_token
    rescue Exception => e
      log(500, 'UpdateSaplingFieldOptionsFromAdp - Access Token Retrieval - ERROR', { message: e.message })
      return
    end

    begin
      @certificate = configuration.retrieve_certificate
    rescue Exception => e
      log(500, 'UpdateSaplingFieldOptionsFromAdp - Certificate Retrieval - ERROR', { message: e.message })
    end

    return unless access_token.present? && certificate.present?

    sync_onboarding_templates()
  end

  private

  def sync_onboarding_templates()
    begin
      if !company.sync_adp_templates_by_v2 
        onboarding_templates = select_and_sync_templates(fetch_onboarding_templates(access_token, certificate), 'v1')
      elsif company.sync_adp_templates_by_v2
        onboarding_templates = {}
        onboarding_templates[env_sym] = format_v2_templates(fetch_templates('US'), fetch_templates('CA'), fetch_templates('INT', true))
      end

      update_integration(onboarding_templates)
    rescue Exception => e
      log(500, "UpdateOnboardingTemplatesFromAdp #{enviornment} - ERROR", { message: e.message })
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end


  def select_and_sync_templates(response, version, is_int = false)
    set_correlation_id(response)
    onboarding_templates = {env_sym => []}

    if response&.status == 200
      meta = JSON.parse(response&.body)
      onboarding_templates_lists = select_supported_templates(fetch_templates_from_response(meta, version), version, is_int) rescue []

      onboarding_templates[env_sym] = onboarding_templates_lists      
    else
      log(response.status, "UpdateOnboardingTemplatesFromAdp #{enviornment} - IntegrationMetadata - ERROR", { message: response.inspect })
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end

    return onboarding_templates
  end

  def update_integration(onboarding_templates)
    ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
    adp_wfn_api.integration_credentials.find_by(name: 'Onboarding Templates').update_column(:dropdown_options, onboarding_templates)
    @adp_wfn_api.update_column(:synced_at, DateTime.now) if @adp_wfn_api
  end

  def select_supported_templates(onboarding_templates, version, is_int = false)
    return [] unless onboarding_templates.present?
    supported_onboarding_templates = ['HR + Payroll (System)', 'HR + Payroll + Time (System)', 'HR + Time (System)', 'HR Only (System)', 'Applicant Onboard', 'Applicant Onboard US']
    seleted_onboarding_templates = []

    onboarding_templates.clone.each do |onboarding_template|
      onboarding_template.clone.each do |k,v|
        name = v.split('-')
        if ['shortName', 'longName', 'name'].include?(k)
          onboarding_template['template_name'] = onboarding_template.delete(k)
          onboarding_template['codeValue'] = onboarding_template.delete('code') if version == 'v2'
          onboarding_template['template_name'] = onboarding_template['template_name'].to_s + ' - International' if is_int 
          seleted_onboarding_templates.push(onboarding_template)
        end
      end
    end

    seleted_onboarding_templates.uniq {|template| template['template_name']}
  end

  def format_v2_templates(us_templates, can_templates, int_templates) us_templates[env_sym] + int_templates[env_sym] + can_templates[env_sym] end
  def fetch_templates(identifier, is_int = false) select_and_sync_templates(fetch_v2_onboarding_templates(access_token, certificate, identifier), 'v2', is_int) end
  def fetch_templates_from_response(meta, version) version == 'v2' ? meta["meta"]["/applicantOnboarding/onboardingTemplateCode"]["codeList"]["listItems"] : meta['codeLists'][0]['listItems'] end 
  def env_sym() @env ||= enviornment.downcase.to_sym end
  def helper; HrisIntegrationsService::AdpWorkforceNowU::Helper.new end
  def events; HrisIntegrationsService::AdpWorkforceNowU::Events.new end
  def set_correlation_id(response) @correlation_id = fetch_adp_correlation_id_from_response(response) end
  def log(status, action, result) create_loggings(company, "ADP Workforce Now - #{enviornment}", status, action, result.merge({adp_correlation_id: @correlation_id})) end
end
