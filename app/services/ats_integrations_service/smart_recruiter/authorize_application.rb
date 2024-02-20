class AtsIntegrationsService::SmartRecruiter::AuthorizeApplication
  
  attr_reader :company, :integration

  def initialize(company)
    @company = company
    @integration = fetch_integration(@company)
  end

  def authentication_request_url
    prepare_authetication_url
  end

  def redirect_uri
    if ENV['IS_AZURE_INFRA'].present?
      "#{ENV['CALLBACK_URL']}smart_recruiters_authorize/callback"
    else 
      REDIRECT_URL
    end
  end

  def prepare_authetication_url
    state = JsonWebToken.encode({company_id: @company.id, instance_id: @integration&.id, subdomain: @company.subdomain})
    { url: "https://www.smartrecruiters.com/identity/oauth/allow?client_id=#{@integration&.client_id}&redirect_uri=#{redirect_uri}&scope=candidates_read%20jobs_read%20company_read&state=#{state}"}
  end

  def fetch_integration(company)
    instance = company.integration_instances.where(api_identifier: "smart_recruiters").take
    if instance.present? && instance.client_id.blank? && instance.client_secret.blank?
      instance.client_id(ENV['SMART_RECRUITER_CLIENT_ID'])
      instance.client_secret(ENV['SMART_RECRUITER_CLIENT_SECRET'])
    end

    instance
  end
end
