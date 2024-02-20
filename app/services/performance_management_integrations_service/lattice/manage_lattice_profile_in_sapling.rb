class PerformanceManagementIntegrationsService::Lattice::ManageLatticeProfileInSapling
  attr_reader :company, :integration

  delegate :create_loggings, :fetch_integration, :is_integration_valid?, to: :helper_service

  def initialize(company)
    @company = company
    @integration = fetch_integration(@company)
  end

  def perform

    unless is_integration_valid?(@integration)
      @integration.update_columns(synced_at: DateTime.now, sync_status: 'failed')
      create_loggings(@company, 'Lattice', 404, "Lattice credentials missing - Update from Lattice")
      return
    end

    execute
  end

  private
  
  def update_profile
    ::PerformanceManagementIntegrationsService::Lattice::UpdateLatticeProfileInSapling
      .new(@company, @integration).update
  end

  def execute
    update_profile
  end

  def helper_service
    PerformanceManagementIntegrationsService::Lattice::Helper.new
  end
end