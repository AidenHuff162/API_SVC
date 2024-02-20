module IdentityServer
  class Authenticator
    attr_reader :current_company, :access_token, :decoded_hash, :origin

    delegate :get_user_info, to: :events_service

    def initialize(**kwargs)
      @current_company = kwargs[:current_company]
      @access_token = kwargs[:access_token]
      @origin = kwargs[:origin]
    end

    def perform
      @decoded_hash = decode_access_token
      return if decoded_hash.nil? || Time.zone.now > Time.zone.at(decoded_hash.first['exp'])

      find_user
    end

    def find_user
      find_user_by_sub || fetch_user_from_identity_server
    end

    private

    def fetch_user_from_identity_server
      response = get_user_info(access_token)
      user_info = JSON.parse(response.body)
      user = current_company.users.find_by(email: user_info['email'])
      return if user.nil?

      user.update_column(:identity_server_id, decoded_hash.first['sub'])
      user
    rescue Exception => e
      log_errors(e, decoded_hash)
      nil
    end

    def log_errors(error, decoded_hash)
      LoggingService::IntegrationLogging.new.create(current_company,
                                                    'IdentityServer',
                                                    'Fetch User info from IdentityServer',
                                                    { sub: decoded_hash.first['sub'] },
                                                    { error: error.message, origin: origin }, 500)
    end

    def find_user_by_sub
      current_company.users.find_by(identity_server_id: decoded_hash.first['sub'])
    end

    def events_service
      @events_service ||= IdentityServer::Events.new
    end

    def decode_access_token
      JsonWebToken.validate(access_token, origin)
    end
  end
end
