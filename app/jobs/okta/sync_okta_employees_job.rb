class Okta::SyncOktaEmployeesJob < Okta::Base

  def perform(integration_id)

    okta_integration = IntegrationInstance.find_by(id: integration_id)
    return unless okta_integration.present?

    company = okta_integration.company
    return unless company

    unless okta_integration.identity_provider_sso_url.present?
      log(company, 'Sync', nil, {error: "Identity provider SSO url doesn't exists for Okta."}, 404)
      return
    end

    un_synced_users_emails = company.users.where(okta_id: nil).pluck(:email, :personal_email)
    uri = URI.parse("https://#{fetch_okta_host(okta_integration.identity_provider_sso_url)}/api/v1/users?limit=200")
    loop do
      next_uri = sync_employees(uri, okta_integration, un_synced_users_emails)
      break if next_uri.blank?
      uri = URI.parse(next_uri)
    end
  end
end
