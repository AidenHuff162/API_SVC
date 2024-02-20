module IntegrationErrors
  class SendIntegrationApiTestingErrorNotificationToSlackJob < ApplicationJob
    queue_as :manage_api_key_testing

    def perform

      if ENV['API_TEST_SLACK_WEBHOOK_URL'].present?
        Company.all.try(:find_each) do |company|
          integration_type = company.integration_type
          @current_company = company
            if company.integration_types.include?('bamboo_hr') && company.integration_types.exclude?('adp_wfn_us') && company.integration_types.exclude?('adp_wfn_can')
              send_bamboo_notification(company)
            elsif company.integration_types.include?('adp_wfn_us') && company.integration_types.exclude?('bamboo_hr')
              send_adp_us_notification(company)
            elsif company.integration_types.include?('adp_wfn_can') && company.integration_types.exclude?('bamboo_hr')
              send_adp_can_notification(company)
            elsif company.integration_types.include?('bamboo_hr') && ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| company.integration_types.include?(api_name) }.present?
              send_bamboo_notification(company)
              send_adp_us_notification(company)
              send_adp_can_notification(company)
            elsif company.integration_types.include?('adp_wfn_us') && company.integration_types.include?('adp_wfn_can')
              send_adp_us_notification(company)
              send_adp_can_notification(company)
            end
          send_notificaton_to_integrations(company)
        end
      end
    end

    private

    def send_namely_notification(company)
      message = ""
      integration = get_namely_credentials(company) rescue nil

      if integration.present?
        if !integration.company_url.present? && integration.permanent_access_token.present?
          message = "#{company.name}: Sub-domain don't present for Namely."
        elsif integration.company_url.present? && !integration.permanent_access_token.present?
          message = "#{company.name}: Access-Token don't present for Namely."
        elsif !integration.company_url.present? && !integration.permanent_access_token.present?
          message = "#{company.name}: Sub-domain and Access-Token don't present for Namely."
        else
          begin
            namely = Namely::Connection.new(access_token: integration.permanent_access_token, subdomain: integration.company_url)
            namely.job_titles.all.inspect
          rescue Exception => e
            message = "#{company.name} Access-Token/Sub-domain have been updated or expired for Namely."
          end
        end
      else
        message = "#{company.name}: Sub-domain and Access-Token don't present for Namely."
      end

      send_notification(message) if message.present?
    end

    def send_bamboo_notification(company)
      message = ""
      integration = company.integration_instances.where(api_identifier: 'bamboo_hr', state: :active)&.take rescue nil

      if integration.present?
        if !integration.subdomain.present? && integration.api_key.present?
          message = "#{company.name}: Sub-domain don't present for BambooHR."
        elsif integration.subdomain.present? && !integration.api_key.present?
          message = "#{company.name}: Api-key don't present for BambooHR."
        elsif !integration.subdomain.present? && !integration.api_key.present?
          message = "#{company.name}: Sub-domain and Api-key don't present for BambooHR."
        else
          begin
            response = HTTParty.get("https://api.bamboohr.com/api/gateway.php/#{integration.subdomain}/v1/meta/lists",
              headers: { accept: "application/json" },
              basic_auth: { username: integration.api_key, password: 'x' }
            )

            if response['X-Bamboohr-Error-Message'] == "API key not provided or invalid"
              message = "#{company.name}: Api-key/Sub-domain have been updated or expired for BambooHR."
            end
          rescue Exception => e
          end
        end
      else
        message = "#{company.name}: Sub-domain and Api-key don't present for BambooHR."
      end

      send_notification(message) if message.present?
    end

    def send_adp_can_notification(company)
      message = ""
      integration = company.integration_instances.where(api_identifier: 'adp_wfn_can', state: :active).first rescue nil

      if integration.present?
        if !integration.client_id.present? && integration.client_secret.present?
          message = "#{company.name}: Client-ID don't present for ADP Workforce Now."
        elsif integration.client_id.present? && !integration.client_secret.present?
          message = "#{company.name}: Client-Secret don't present for ADP Workforce Now."
        elsif !integration.client_id.present? && !integration.client_secret.present?
          message = "#{company.name}: Client-ID and CLient-Secret don't present for ADP Workforce Now."
        else
          begin
            require 'adp/connection'
            config = {
              'clientID' =>       integration.client_id,
              'clientSecret' =>   integration.client_secret,
              'sslCertPath' =>    'config/certs/apiclient_certificate.pem',
              'sslKeyPath' =>     'config/certs/apiclient_private.key',
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
          rescue Exception => e
            if e.to_s == "uninitialized constant Adp::Connection::ApiConnection::ADPConnectionException"
              message = "#{company.name}: Client-ID/Client-Secret have been updated or expired for ADP Workforce Now."
            end
          end
        end
      else
        message = "#{company.name}: Client-ID and Client-Secret don't present for ADP Workforce Now."
      end

      send_notification(message) if message.present?
    end

    def send_adp_us_notification(company)
      message = ""
      integration = company.integration_instances.where(api_identifier: 'adp_wfn_us', state: :active).first rescue nil

      if integration.present?
        if !integration.client_id.present? && integration.client_secret.present?
          message = "#{company.name}: Client-ID don't present for ADP Workforce Now."
        elsif integration.client_id.present? && !integration.client_secret.present?
          message = "#{company.name}: Client-Secret don't present for ADP Workforce Now."
        elsif !integration.client_id.present? && !integration.client_secret.present?
          message = "#{company.name}: Client-ID and CLient-Secret don't present for ADP Workforce Now."
        else
          begin
            require 'adp/connection'
            config = {
              'clientID' =>       integration.client_id,
              'clientSecret' =>   integration.client_secret,
              'sslCertPath' =>    'config/certs/apiclient_certificate.pem',
              'sslKeyPath' =>     'config/certs/apiclient_private.key',
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
          rescue Exception => e
            if e.to_s == "uninitialized constant Adp::Connection::ApiConnection::ADPConnectionException"
              message = "#{company.name}: Client-ID/Client-Secret have been updated or expired for ADP Workforce Now."
            end
          end
        end
      else
        message = "#{company.name}: Client-ID and Client-Secret don't present for ADP Workforce Now."
      end

      send_notification(message) if message.present?
    end

    def send_notification(message)
      payload = TeamService::BuildPayload.new.prepare_payload(message, 'Integration credentials testing', 'Sapling')
      RestClient.post ENV['API_TEST_SLACK_WEBHOOK_URL'], payload.to_json, {content_type: :json, accept: :json} rescue nil
      slack_integration = @current_company.integration_instances.find_by(api_identifier: 'slack_communication', state: :active)
      slack_integration.update_column(:synced_at, DateTime.now) if slack_integration
    end

    def send_notificaton_to_integrations(company)
      
      send_namely_notification(company) if company.is_namely_integrated
    end

    def get_namely_credentials(company)
      ::HrisIntegrationsService::Namely::Helper.new.fetch_integration(company)
    end
  end
end
