module IntegrationSerializer
  class Basic < ActiveModel::Serializer
    attributes :api_name, :saml_certificate, :identity_provider_sso_url
  end
end
