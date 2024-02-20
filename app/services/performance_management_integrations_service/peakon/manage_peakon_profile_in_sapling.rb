class PerformanceManagementIntegrationsService::Peakon::ManagePeakonProfileInSapling
  attr_reader :company, :integration

  delegate :create_loggings, :fetch_integration, :is_integration_valid?, to: :helper_service

  def initialize(company)
    @company = company
    @integration = fetch_integration(@company)
  end

  def perform

    unless is_integration_valid?(@integration)
      create_loggings(@company, 'Peakon', 404, "Peakon credentials missing - Update from Peakon")
      return
    end

    execute
    @integration.update_column(:synced_at, DateTime.now)
  end

  private
  
  def update_profile
    ::PerformanceManagementIntegrationsService::Peakon::UpdatePeakonProfileInSapling
      .new(@company, @integration).update
  end

  def execute
    update_profile
  end

  def helper_service
    PerformanceManagementIntegrationsService::Peakon::Helper.new
  end
end