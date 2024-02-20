class AccountPropertiesSyncJob
  include Sidekiq::Worker
  sidekiq_options :queue => :company_attributes_sync, :backtrace => true

  def perform(company_id)
    company = Company.find_by_id company_id
    CompanyAttributesSyncService::SyncCompanyData.new(company).perform if company
  end

end
