class HrisIntegrationsService::Deputy::ManageDeputyProfileInSapling

  attr_reader :company, :integration

  delegate :create_loggings, :fetch_integration, :is_integration_valid?, to: :helper_service

  def initialize(company)
    @company = company
    @integration = fetch_integration(@company)
  end

  def perform
    @integration.in_progress!
    unless is_integration_valid?(@integration)
      @integration.failed!
      create_loggings(@company, 'Deputy', 404, "Deputy credentials missing - Fetching Profiles")
      return
    end

    execute
    @integration.update_columns(sync_status: IntegrationInstance.sync_statuses[:succeed], synced_at: DateTime.now)
  end

  private

  def update_profile
    HrisIntegrationsService::Deputy::UpdateDeputyProfileInSapling
      .new(@company, @integration).update
  end

  def execute
    update_profile
  end

  def helper_service
    HrisIntegrationsService::Deputy::Helper.new
  end
end