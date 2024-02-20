class CompanyAttributesSyncService::SyncIntercomData

  attr_reader :company

  delegate :common_properties, :create_loggings, to: :helper_service

  def initialize(company)
    @company = company
  end

  def perform
    begin
      intercom = Intercom::Client.new(token: ENV['INTERCOM_ACCESS_TOKEN'])
      intercom.companies.create(company_properties)
     rescue Exception => e
      create_loggings(e.message, company)
    end
  end

  private

  def company_properties
    {
      name: company.name,
      company_id: ENV['FRONTEND_MAPPING_SERVER_NAME'] == 'production' ? company.id : "#{company.id}-#{ENV['FRONTEND_MAPPING_SERVER_NAME']}" ,
      custom_attributes: common_properties(company).merge({company_domain: company.domain})
    }
  end

  def helper_service
    CompanyAttributesSyncService::Helper.new
  end
  
end
