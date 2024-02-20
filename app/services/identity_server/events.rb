module IdentityServer
  class Events
    attr_reader :current_company, :base_url, :callback_url

    BASE_URL = ENV['IDENTITY_SERVER_URL']
    CLIENT_ID = ENV['IDS_CLIENT_ID']

    def get_user_info(token)
      HTTParty.get("#{BASE_URL}/connect/userinfo",
                   body: '',
                   headers: { accept: 'application/json', authorization: "Bearer #{token}" })
    end

    def get_signing_keys
      HTTParty.get("#{BASE_URL}/.well-known/openid-configuration/jwks")
    end
  end
end
