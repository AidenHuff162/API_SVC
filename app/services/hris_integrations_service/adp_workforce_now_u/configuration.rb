class HrisIntegrationsService::AdpWorkforceNowU::Configuration
	attr_reader :adp_workforce_api, :certificate, :access_token

  if Rails.env.development?
    ADP_CERTIFICATE_PATH = "config/certs/apiclient_certificate.pem"
    ADP_KEY_PATH = "config/certs/apiclient_private.key"
  elsif ENV['FETCH_ENVS_FROM_REMOTE_URL'] == 'true'
    ADP_CERTIFICATE_PATH = File.join(Dir.home, ENV['ENV_LOCAL_STORAGE_PATH'] + "/config/.ssl.temp", 'adpapiclient_certificate.pem')
    ADP_KEY_PATH = File.join(Dir.home, ENV['ENV_LOCAL_STORAGE_PATH'] + "/config/.ssl.temp", 'adpapiclient_private.key')
  else
    ADP_CERTIFICATE_PATH = File.join(Dir.home, "www/sapling/shared/config", 'adpapiclient_certificate.pem')
    ADP_KEY_PATH = File.join(Dir.home, "www/sapling/shared/config", 'adpapiclient_private.key')
  end

	def initialize(adp_workforce_api)
    @adp_workforce_api = adp_workforce_api
	end

	def adp_workforce_api_initialized?
    adp_workforce_api.present? && adp_workforce_api.client_id.present? && adp_workforce_api.client_secret.present?
  end
  
  # :nocov:
  def retrieve_access_token
  	return unless adp_workforce_api_initialized?
    retries ||= 1

    begin
      connection = create_connection
      connection.access_token.token
    rescue Exception => e
      puts "ADP Exception: #{e.inspect}"
      sleep 4
      
      retry if (retries += 1) < 10
      
      if retries == 10
        raise
      end
    end
  end

  def retrieve_certificate
  	return unless adp_workforce_api_initialized?
    retries ||= 1

    begin
  	 create_certificate
    rescue Exception => e
      puts "ADP Exception: #{e.inspect}"
      sleep 4
      
      retry if (retries += 1) < 10
      if retries == 10
        raise
      end
    end
  end

  private

  def initialize_configuration
    configuration = {
      'clientID' =>       adp_workforce_api.client_id,
      'clientSecret' =>   adp_workforce_api.client_secret,
      'sslCertPath' =>    ADP_CERTIFICATE_PATH,
      'sslKeyPath' =>     ADP_KEY_PATH,
      'sslKeyPass' =>     '',
      'tokenServerURL' => "https://api.adp.com/auth/oauth/v2/token",
      'disconnectURL' =>  "https://accounts.adp.com/auth/oauth/v2/logout",
      'apiRequestURL' =>  "https://api.adp.com",
      'responseType' =>   'code',
      'defaultexpiration' => 3600,
      'grantType' =>      'client_credentials',
    }
  end

  def create_connection
    configuration = initialize_configuration
    client_credential_configuration = Adp::Connection::ClientCredentialConfiguration.new(configuration)
    connection = Adp::Connection::ApiConnectionFactory::createConnection(client_credential_configuration)
    connection.connect()

    connection
  end

  def create_certificate
    certificate = OpenSSL::SSL::SSLContext.new
    certificate.cert = OpenSSL::X509::Certificate.new(File.read(ADP_CERTIFICATE_PATH))
    certificate.key = OpenSSL::PKey::RSA.new(File.read(ADP_KEY_PATH))

    certificate
  end
  # :nocov:
end
