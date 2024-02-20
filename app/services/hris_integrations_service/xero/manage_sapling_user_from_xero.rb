class HrisIntegrationsService::Xero::ManageSaplingUserFromXero

  attr_reader :company, :xero
  
  delegate :fetch_integration, to: :helper_service

  def initialize(company)
    @company = company
    @xero = fetch_integration(company)
  end

  def perform
    execute
    xero.update_columns(synced_at: DateTime.now, unsync_records_count: update_service.fetch_sapling_users.uniq.count ) if xero.present?
  end

  private
  
  def update_profile
    update_service.update
  end

  def execute
    update_profile
  end

  def update_service
    @service ||= HrisIntegrationsService::Xero::UpdateSaplingUserFromXero.new(company, xero)
  end

  def helper_service
    ::HrisIntegrationsService::Xero::Helper.new
  end
end