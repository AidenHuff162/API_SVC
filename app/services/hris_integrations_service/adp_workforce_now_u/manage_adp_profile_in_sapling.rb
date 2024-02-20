class HrisIntegrationsService::AdpWorkforceNowU::ManageAdpProfileInSapling
  attr_reader :company, :adp_wfn_enviornment

  delegate :initialize_adp_wfn_us, :initialize_adp_wfn_can, to: :helper_service

  def initialize(company, adp_wfn_enviornment = nil)
    @company = company
    @adp_wfn_enviornment = adp_wfn_enviornment
  end

  def update
    if adp_wfn_enviornment.present?
      update_by_enviornment
    else
      update_by_company_integration_type
    end
  end

  private

  def update_by_enviornment
    if adp_wfn_enviornment == 'adp_wfn_us'
      fetch_from_adp_us
    elsif adp_wfn_enviornment == 'adp_wfn_can'
      fetch_from_adp_can
    end
  end

  def update_by_company_integration_type
    if company.integration_types.include?('adp_wfn_us') && company.integration_types.exclude?('adp_wfn_can')
      fetch_from_adp_us
    elsif company.integration_types.include?('adp_wfn_can') && company.integration_types.exclude?('adp_wfn_us')
      fetch_from_adp_can
    elsif company.integration_types.include?('adp_wfn_us') && company.integration_types.include?('adp_wfn_can')
      fetch_from_adp_us_and_can
    end
  end

  def update_sapling_field_options(integration)
    ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingCustomFieldOptionsFromAdp.new(integration).sync
    ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingGroupOptionsFromAdp.new(integration).sync
    ::HrisIntegrationsService::AdpWorkforceNowU::UpdateCompanyCodesFromAdp.new(integration).sync if integration.enable_company_code.present?
  end

  def fetch_from_adp(adp_wfn_api)
    return unless adp_wfn_api.present?

    if adp_wfn_api.can_import_data.blank? && company.domain == 'popsugar.saplingapp.io'
      return 
    end
    
    update_service = ::HrisIntegrationsService::AdpWorkforceNowU::UpdateAdpProfileInSapling.new(adp_wfn_api)

    update_sapling_field_options(adp_wfn_api)
    return unless adp_wfn_api.can_import_data.present?
    update_service.fetch_associate_ids
    update_service.fetch_updates
  end

  def fetch_from_adp_us
    adp_wfn_us_api = initialize_adp_wfn_us(company)
    fetch_from_adp(adp_wfn_us_api)
  end

  def fetch_from_adp_can
    adp_wfn_can_api = initialize_adp_wfn_can(company)
    fetch_from_adp(adp_wfn_can_api)
  end

  def fetch_from_adp_us_and_can
    fetch_from_adp_us
    fetch_from_adp_can
  end

  def helper_service
    HrisIntegrationsService::AdpWorkforceNowU::Helper.new
  end
end
