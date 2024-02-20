class Okta::SendEmployeeToOktaJob < Okta::Base

  def perform(user_id)
    user = User.find_by_id(user_id)
    return if !user.present? || user.super_user

    okta_integration = user.company.integration_instances.find_by(api_identifier: 'okta', state: :active)

    return unless okta_integration.present? && okta_integration.enable_create_profile
    unless okta_integration.identity_provider_sso_url.present?
      log(user.company, 'Create', nil, {error: "Identity provider SSO url doesn't exists for Okta."}, 404)
      return
    end

    if !user.okta_id.present?
      uri = URI.parse("https://#{fetch_okta_host(okta_integration.identity_provider_sso_url)}/api/v1/users?activate=false")
      response, user_profile = send_profile_to_okta(user, uri, okta_integration)
      if response.present?
        log(user.company, 'Create', user_profile, {result: response.body.inspect}, (JSON.parse(response.body)['errorCode'].present? ? 500 : 200))
      end
    end
  end
end
