class CompanyAttributesSyncService::SyncCompanyData
  attr_reader :company

  def initialize(company)
    @company = company
  end

  def perform
    sync_heap_data
    sync_intercom_data
  end

  private

  def sync_heap_data
    CompanyAttributesSyncService::SyncHeapData.new(company).perform
  end

  def sync_intercom_data
    CompanyAttributesSyncService::SyncIntercomData.new(company).perform
  end

end
