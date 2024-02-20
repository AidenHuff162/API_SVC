class HrisIntegrationsService::Paylocity::ManagePaylocityProfileInSapling

  attr_reader :company, :integrations

  delegate :create_loggings, :fetch_integration, :is_integration_valid?, to: :helper_service

  def initialize(company)
    @company = company
    @integrations = fetch_integration(@company)
  end

  def perform
    @integrations.each do |integration|
      next unless ['web_pay_only', 'onboarding_webpay'].include?(integration.integration_type)
      integration.in_progress!
      unless is_integration_valid?(integration)
        integration.failed!
        create_loggings(@company, 'Action missing' , 404, {message: 'Paylocity credentials missing - Update from Paylocity'})
        return
      end

      execute(integration)
      integration.succeed!
      integration.update_column(:synced_at, DateTime.now)
    end
  end

  private
  
  def update_profile(integration)
    ::HrisIntegrationsService::Paylocity::UpdatePaylocityProfileInSapling
      .new(@company, integration).update
  end

  def execute(integration)
    update_profile(integration)
  end

  def helper_service
    ::HrisIntegrationsService::Paylocity::Helper.new
  end
end