module SAMLSettings
  extend ActiveSupport::Concern

  def saml_settings
    settings = OneLogin::RubySaml::Settings.new
    settings.assertion_consumer_service_url = "https://#{request.host}/api/v1/auth/omniauth_callbacks/consume_saml_response"
    settings.idp_sso_target_url = current_company.get_saml_sso_target_url if current_company.authentication_type != 'active_directory_federation_services'
    settings.idp_cert = current_company.get_saml_idp_cert
    if current_company.authentication_type == "ping_id"
      settings.issuer  = "https://#{request.host}"
    else
      settings.name_identifier_format = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
    end
    
    if current_company.id == 37 || current_company.subdomain == 'hci'
      settings.name_identifier_format = "urn:oasis:names:tc:SAML:2.0:nameid-format:transient" if current_company.id == 37
      settings.issuer  = "https://#{request.host}"
      settings.certificate = current_company.self_signed_attributes["cert"]
      settings.private_key = current_company.self_signed_attributes["private_key"]
      settings.security[:authn_requests_signed]   = true
    end
    settings
  end

  def saml_shib_settings
    settings = OneLogin::RubySaml::Settings.new
    settings.assertion_consumer_service_url = "https://#{request.host}/api/v1/auth/omniauth_callbacks/consume_saml_response"
    settings.idp_sso_target_url = current_company.get_saml_sso_target_url if current_company.authentication_type != 'active_directory_federation_services'
    settings.idp_cert = current_company.get_saml_idp_cert
    settings.name_identifier_format = "urn:oasis:names:tc:SAML:2.0:nameid-format:transient"
    settings.issuer  = "https://#{request.host}"
    settings.certificate = current_company.self_signed_attributes["cert"]
    settings.private_key = current_company.self_signed_attributes["private_key"]
    settings
  end

  def saml_martin_settings
    settings = OneLogin::RubySaml::Settings.new
    settings.assertion_consumer_service_url = "https://#{request.host}/api/v1/auth/omniauth_callbacks/consume_saml_response"
    settings.idp_sso_target_url = current_company.get_saml_sso_target_url
    settings.idp_cert = current_company.get_saml_idp_cert
    settings.name_identifier_format = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
    settings.issuer  = "https://#{request.host}"
    settings.certificate = current_company.self_signed_attributes["cert"]
    settings.private_key = current_company.self_signed_attributes["private_key"]
    settings.security[:authn_requests_signed]   = true
    settings
  end

end
