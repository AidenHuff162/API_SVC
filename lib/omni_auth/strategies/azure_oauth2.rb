require 'omniauth/strategies/oauth2'
require 'jwt'
require 'uri'

module OmniAuth
  module Strategies
    class AzureOauth2 < OmniAuth::Strategies::OAuth2
      BASE_AZURE_URL = 'https://login.microsoftonline.com'

      option :name, 'azure_oauth2'

      option :tenant_provider, nil

      # AD resource identifier
      option :resource, '00000002-0000-0000-c000-000000000000'

      # tenant_provider must return client_id, client_secret and optionally tenant_id and base_azure_url
      args [:tenant_provider]

      def client
        
        if options.tenant_provider
          provider = options.tenant_provider.new(self)
        else
          provider = options  # if pass has to config, get mapped right on to options
        end

        options.client_id = provider.client_id
        options.client_secret = provider.client_secret
        options.tenant_id =
          provider.respond_to?(:tenant_id) ? provider.tenant_id : 'common'
        options.base_azure_url =
          provider.respond_to?(:base_azure_url) ? provider.base_azure_url : BASE_AZURE_URL

        options.authorize_params = provider.authorize_params if provider.respond_to?(:authorize_params)
        options.authorize_params.domain_hint = provider.domain_hint if provider.respond_to?(:domain_hint) && provider.domain_hint
        options.authorize_params.prompt = request.params['prompt'] if defined? request && request.params['prompt']
        options.client_options.authorize_url = "#{options.base_azure_url}/#{options.tenant_id}/oauth2/authorize"
        options.client_options.token_url = "#{options.base_azure_url}/#{options.tenant_id}/oauth2/token"
        super
      end

      uid {
        raw_info['sub']
      }
      info do
        {

          name: raw_info['name'],
          nickname: raw_info['unique_name'],
          first_name: raw_info['given_name'],
          last_name: raw_info['family_name'],
          email: raw_info['email'] || raw_info['upn'],
          oid: raw_info['oid'],
          tid: raw_info['tid']
        }

      end

      def token_params
        azure_resource = request.env['omniauth.params'] && request.env['omniauth.params']['azure_resource']
        super.merge(resource: azure_resource || options.resource)
      end

      def callback_url
        REDIRECT_URL
        # host_without_port = full_host.gsub('http:', 'https:').gsub(':443', '')
        # options[:redirect_uri] || (host_without_port + script_name + callback_path)
      end

      def raw_info
        # it's all here in JWT http://msdn.microsoft.com/en-us/library/azure/dn195587.aspx
        @raw_info ||= ::JWT.decode(access_token.token, nil, false).first
      end

      def fail!(message_key, exception = nil)
        env['omniauth.error'] = exception
        env['omniauth.error.type'] = message_key.to_sym
        env['omniauth.error.strategy'] = self

        if exception
          log :error, "Authentication failure! #{message_key}: #{exception.class}, #{exception.message}"
        else
          log :error, "Authentication failure! #{message_key} encountered."
        end

        Rack::Response.new(['302 Moved'], 302, 'Location' => env['omniauth.origin'] || "/#{'hr/' if ENV['IS_AZURE_INFRA'].present? }").finish
        # OmniAuth.config.on_failure.call(env)
      end

      def authorize_params # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        options.authorize_params[:state] = state

        if OmniAuth.config.test_mode
          @env ||= {}
          @env["rack.session"] ||= {}
        end

        params = options.authorize_params
                        .merge(options_for("authorize"))
                        .merge(pkce_authorize_params)

        session["omniauth.pkce.verifier"] = options.pkce_verifier if options.pkce
        session["omniauth.state"] = params[:state]

        params
      end

      def pkce_authorize_params
        return {} unless options.pkce

        options.pkce_verifier = SecureRandom.hex(64)

        # NOTE: see https://tools.ietf.org/html/rfc7636#appendix-A
        {
          :code_challenge => options.pkce_options[:code_challenge]
                                    .call(options.pkce_verifier),
          :code_challenge_method => options.pkce_options[:code_challenge_method],
        }
      end

      def state
        JsonWebToken.encode({subdomain: subdomain, instance_id: instance_id, azure_login: true})
      end

      def subdomain
        request.host.split('.')[0]
      end

      def instance_id
        IntegrationInstance.joins(:company).where(api_identifier: 'adfs_productivity', companies:{subdomain: subdomain} )&.take&.id
      end
    end
  end
end