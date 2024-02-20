class IntegrationsService::IntegrationChangeManagement
  attr_reader :company, :integration

  def initialize(company)
    @company = company
    @integration = initialize_integration
  end

  def manage_profile_setup_on_integration_change
    return unless @integration.present?
    @integration.manage_profile_setup_on_integration_change
  end

  def manage_phone_format_conversion
    return unless @integration.present?
    @integration.manage_phone_data_migration_on_integration_change
  end

  private

  def initialize_integration
    type = @company.integration_type
    if type == "no_integration"
      return IntegrationsService::NoIntegration.new(@company)
    elsif @company.integration_types.include?('bamboo_hr') && @company.integration_types.exclude?('adp_wfn_us') && @company.integration_types.exclude?('adp_wfn_can')
      return IntegrationsService::Bamboo.new(@company)
    elsif type == "paylocity"
      return IntegrationsService::Paylocity.new(@company)
    elsif ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| @company.integration_types.include?(api_name) }.present? && @company.integration_types.exclude?('bamboo_hr')
      return IntegrationsService::AdpWorkforceNow.new(@company)
    elsif @company.integration_types.include?('bamboo_hr') && ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| @company.integration_types.include?(api_name) }.present?
      return IntegrationsService::AdpWorkforceNowAndBamboo.new(@company)
    end
  end
end
