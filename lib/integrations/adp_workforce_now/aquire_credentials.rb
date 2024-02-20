module Integrations
  module AdpWorkforceNow
    class AquireCredentials

      require 'adp/connection'
      require 'rails/all'
      require 'http'
      require 'tempfile'

      def initialize(organization_oid, company_id, environment)
        @organization_oid = organization_oid
        @company = Company.find_by id: company_id
        @environment = environment
        @adp_certificate_path = File.join(Dir.home, ENV['ENV_LOCAL_STORAGE_PATH'] + "/config/.ssl.temp", 'adpapiclient_certificate.pem')
        @adp_key_path = File.join(Dir.home, ENV['ENV_LOCAL_STORAGE_PATH'] + "/config/.ssl.temp", 'adpapiclient_private.key')
      end

      def fetch_configuration_credentials
        @environment == 'US' ? {client_id: ENV['ADP_US_CLIENT_ID'], client_secret: ENV['ADP_US_CLIENT_SECRET']} : {client_id: ENV['ADP_CAN_CLIENT_ID'], client_secret: ENV['ADP_CAN_CLIENT_SECRET']}
      end

      def fetch_adp_wfn_api_name
        @environment == 'US' ? 'adp_wfn_us' : 'adp_wfn_can'
      end

      def fetch_and_save_ids
        return unless @environment.present?

        data = {}

        if @organization_oid.present? && @company.present?
          begin
            puts "RETRIEVING ADP WORFORCE-NOW CREDENTIALS FOR OrganizationOID: #{@organization_oid}"

            adp_certificate = File.read(@adp_certificate_path)
            adp_key = File.read(@adp_key_path)
            configuration_credentials = fetch_configuration_credentials 

            config = {
              'clientID' =>       configuration_credentials[:client_id],
              'clientSecret' =>   configuration_credentials[:client_secret],
              'sslCertPath' =>    @adp_certificate_path,
              'sslKeyPath' =>     @adp_key_path,
              'sslKeyPass' =>     '',
              'tokenServerURL' => "https://api.adp.com/auth/oauth/v2/token",
              'disconnectURL' =>  "https://accounts.adp.com/auth/oauth/v2/logout",
              'apiRequestURL' =>  "https://api.adp.com",
              'responseType' =>   'code',
              'defaultexpiration' => 3600,
              'grantType' =>      'client_credentials',
            }

            clientcredential_config = Adp::Connection::ClientCredentialConfiguration.new(config)
            connection = Adp::Connection::ApiConnectionFactory::createConnection(clientcredential_config)
            connection.connect()
            access_token = connection.access_token.token

            certificate = OpenSSL::SSL::SSLContext.new
            certificate.cert = OpenSSL::X509::Certificate.new(adp_certificate)
            certificate.key = OpenSSL::PKey::RSA.new(adp_key)

            data = { "events": [{
              "serviceCategoryCode": {
                "codeValue": "core"
              },
              "eventNameCode": {
                "codeValue": "consumer-application-subscription-credential.read"
              },
              "data": {
                "transform": {
                  "queryParameter": "$filter=subscriberOrganizationOID eq '#{@organization_oid}'"
                }
              }
            }] }
            
            response = fetch_credentials(access_token, certificate, data)
            response = JSON.parse(response.body)

            puts response
            credentials = response['events'][0]['data']['output']['consumerApplicationSubscriptionCredentials'][0]

            unless credentials.present?
              log("Received empty credentials from ADP - #{@environment} for company #{@company.name} - Please ask #{@company.name} to review the permissions of 'Sapling Technologies Data Connector' in their consent manager or contact ADP", data, response, 404)
              return
            end
            
            log("Acquired client credentials from ADP - #{@environment}, for organization id #{@organization_oid} and company #{@company.name}", data, response, 200)

            client_id = credentials['clientID']
            client_secret = credentials['clientSecret']

            api_name = fetch_adp_wfn_api_name

            if client_id.present? && client_secret.present?
              current_integration = @company.integration_instances.where(api_identifier: api_name)

              if current_integration.present?
                current_integration.client_secret(client_secret)
                current_integration.client_id(client_id)
                current_integration.filters ({location_id: ['all'], team_id: ['all'], employee_type: ['all']})

              else
                adp_inventory = IntegrationInventory.find_by_api_identifier(api_name)
                attributes = { api_identifier: api_name, filters: {location_id: ['all'], team_id: ['all'], employee_type: ['all']},
                               state: :active, integration_inventory_id: adp_inventory.id, company_id: @company.id, name: 'Instance No.1'}
                instance = @company.integration_instances.create(attributes)
                credential_names = ['Client ID', 'Client Secret', 'Onboarding Templates', 'Can Export Updation', 'Can Import Data', 'Enable Company Code', 'Enable Tax Type']
                credential_names.each do |name|
                  attributes = {name: name, integration_instance_id: instance.id, integration_configuration_id: adp_inventory.integration_configurations.find_by_field_name(name).id }
                  instance.integration_credentials.where("trim(name) ILIKE ?", attributes[:name]).first_or_create(attributes)
                end
                instance.client_id(client_id)
                instance.client_secret(client_secret)
              end
              puts "SUCCESS WHILE RETRIEVING ADP WORFORCE-NOW CREDENTIALS FOR OrganizationOID: #{@organization_oid}"
            end

          rescue Exception => e
            puts "FAILURE WHILE RETRIEVING ADP WORFORCE-NOW CREDENTIALS FOR OrganizationOID: #{@organization_oid}"
            puts e.inspect
            log("Failed to acquire client credentials from ADP #{@environment}, for organization id #{@organization_oid} and company #{@company.name}", data, e.message, 500)
          end
        end
      end

      def fetch_credentials(access_token, certificate, data)
        faraday_connection_adapter(certificate).post 'events/core/v1/consumer-application-subscription-credentials.read' do |req|
          req.headers['Content-Type'] = 'application/json'
          req.headers['accept'] = 'application/json'
          req.headers['authorization'] = "Bearer #{access_token}"
          req.body = data.to_json
        end
      end

      def faraday_connection_adapter(certificate)
        Faraday.new 'https://api.adp.com/', :ssl => {
          :client_cert  => certificate&.cert,
          :client_key   => certificate&.key,
        }
      end

      def log(action, request, response, status)
        LoggingService::IntegrationLogging.new.create(@company, "ADP Workforce Now - #{@environment}", action, request, response, status)
      end
    end
  end
end
