class HrisIntegrationsService::Deputy::ManageDeputyCompanies

  delegate :create_loggings, to: :helper_service

  def create_deputy_company(integration)
    return unless integration.present?
    deputy_companies = fetch_deputy_companies(integration)
    return unless deputy_companies.present?
    
    deputy_companies.try(:each) do |deputy_company|
      integration.company.locations.where('name ILIKE ?', deputy_company['CompanyName'].strip).first_or_create(name: deputy_company['CompanyName'].strip)
    end
  end

  private

  def fetch_deputy_companies(integration)
    begin
      response = HTTParty.get("https://#{integration.subdomain}/api/v1/resource/Company",
        headers: { accept: 'application/json', authorization: "Bearer #{integration.access_token}" }
      )
      
      parsed_response = JSON.parse(response.body)

      if response.ok?
        create_loggings(integration.company, 'Deputy', response.code, "Fetch deputy locations (companies) - Success", {response: parsed_response})
        return parsed_response
      else
        create_loggings(integration.company, 'Deputy', response.code, "Fetch deputy locations (companies) - Failure", {response: parsed_response})
      end
    rescue Exception => e
      create_loggings(integration.company, 'Deputy', 500, "Fetch deputy locations (companies) - Failure", {response: e.message})
    end
  end

  def helper_service
    HrisIntegrationsService::Deputy::Helper.new
  end
end