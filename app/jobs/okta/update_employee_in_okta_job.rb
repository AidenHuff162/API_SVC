class Okta::UpdateEmployeeInOktaJob < Okta::Base

  def perform(user_id)
    user = User.find_by_id(user_id)
    return if !user.present? || user.super_user

    okta_integration = user.company.integration_instances.find_by(api_identifier: 'okta', state: :active)

    return unless okta_integration.present? && okta_integration.enable_update_profile
    unless okta_integration.identity_provider_sso_url.present?
      log(user.company, 'Update', nil, {error: "Identity provider SSO url doesn't exists for Okta."}, 404)
      return
    end

    if user.okta_id.present?
      uri = URI.parse("https://#{fetch_okta_host(okta_integration.identity_provider_sso_url)}/api/v1/users/#{user.okta_id}")
      response, user_profile = send_profile_to_okta(user, uri, okta_integration)
      log(user.company, 'Update', user_profile, {result: response.body.inspect}, ((response&.body.blank? || JSON.parse(response&.body)['errorCode'].present?) ? 500 : 200))
    end
  end
end
