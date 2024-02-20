class HrisIntegrationsService::Gusto::CreateCompany
  require 'openssl'
  
  attr_reader :company, :user

  delegate :create_loggings, :vendor_domain, :log_statistics, to: :helper_service

  def initialize(company, user)
    @company = company
    @user = user
  end

  def create_company
    account_claim_url 
  end

  private

  def account_claim_url
    content = {
      user: {
        first_name: user.first_name,
        last_name: user.last_name,
        email: user.email
      },
      company: {
        name: company.name
      }
    }

    begin
      response = HTTParty.post("https://#{vendor_domain}/v1/provision",
        body: content,
        headers: { accept: 'application/json', content_type: 'application/json', authorization: "Token #{ENV['GUSTO_API_KEY']}" }
      )

      parsed_response = JSON.parse(response.body)

      if response.code == 201
        loggings(response.code, 'Create Company In Gusto - Success', parsed_response, content, 'Success')
        return parsed_response
      else
        loggings(response.code, 'Create Company In Gusto - Failed', parsed_response, content, 'Failed')
        return parsed_response
      end 
    rescue Exception => e
      loggings(500, 'Create Company In Gusto - Failed', e.message, content, 'Failed')
      return {message: 'Internal Server Error'}
    end

    return
  end

  def loggings(code, action, result, request = nil, status)
    create_loggings(@company, 'Gusto', code, action, {result: result}, request)
    log_statistics(status.downcase, @company)  
  end

  def helper_service
    HrisIntegrationsService::Gusto::Helper.new
  end
end