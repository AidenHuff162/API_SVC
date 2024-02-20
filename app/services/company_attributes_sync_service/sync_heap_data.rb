class CompanyAttributesSyncService::SyncHeapData

  attr_reader :company

  delegate :common_properties, :perform_curl_request, :create_loggings, to: :helper_service

  HEAP_END_POINT = 'https://heapanalytics.com/api/add_account_properties'

  def initialize(company)
    @company = company
  end

  def perform
    begin
      perform_curl_request(HEAP_END_POINT, request_payload)
    rescue Exception => e
      create_loggings(e.message, company)
    end
  end

  private

  def request_payload
    body = {
      'app_id' => ENV['HEAP_APP_ID'],
      'account_id' => company.id,
      'properties' => company_properties
    }
    JSON.dump(body)
  end

  def company_properties
    common_properties(company).merge({company_name: company.name})
  end

  def helper_service
    CompanyAttributesSyncService::Helper.new
  end
  
end
