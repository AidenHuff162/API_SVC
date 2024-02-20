class JsonWebToken
  class << self
    def encode(payload, exp = 90.days.from_now, api_key_token = false)
      payload[:exp] = exp.to_i unless api_key_token
      JWT.encode(payload, ENV['SAPLING_API_ENCODING_KEY'], 'HS256')
    end

    def decode(token)
      body = JWT.decode(token, ENV['SAPLING_API_ENCODING_KEY'], true, { algorithm: 'HS256' })[0]
      HashWithIndifferentAccess.new body
    rescue StandardError => e
      Rails.logger.warn e.message
    end

    def validate(token, _origin)
      jwks = get_signing_keys
      jwks_hash = generate_jwks_hash(jwks)

      JWT.decode(token, nil,
                 true,
                 algorithms: jwks.map { |key| key['alg'] }.compact.uniq,
                 iss: ENV['IDENTITY_SERVER_URL'],
                 verify_iss: true) do |header|
        jwks_hash[header['kid']]
      end
    end

    def get_signing_keys
      Rails.cache.fetch("identity_server_signing_keys", expires_in: 1.day) do
        IdentityServer::Events.new.get_signing_keys['keys']
      end
    end

    def generate_jwks_hash(jwks)
      filtered_jwks = jwks.filter { |key| key['x5c'] }
      Hash[
        filtered_jwks
        .map do |k|
          [
            k['kid'],
            OpenSSL::X509::Certificate.new(
              Base64.decode64(k['x5c'].first)
            ).public_key
          ]
        end
      ]
    end
  end
end
