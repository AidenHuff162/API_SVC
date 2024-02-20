module IntegrationsService
  class DetectIntegrationBasedUrl < ApplicationService
    def initialize(params)
      @params = params
      @state = decode_state
    end

    def call
      "#{prepare_callback_url(state)}#{get_matched_integration_url(get_integration)}"
    rescue
      invalid_request
    end

    private

    attr_reader :params, :state

    def decode_state
      JsonWebToken.decode(params[:state])
    end

    def get_company_id
      state[:company_id] || Company.find_by(subdomain: state['subdomain']).id
    end

    def get_integration
      IntegrationInstance.find_by(id: state[:instance_id], company_id: get_company_id).api_identifier
    end

    def get_matched_integration_url(integration)
      case integration
      when 'xero'
        xero_url
      when 'smart_recruiters'
        smart_recruiters_url
      when 'adfs_productivity'
        azure_ad_url
      end
    end

    def prepare_callback_url(state)
      Rails.env.development? ? "http://#{state['subdomain']}.#{ENV['DEFAULT_HOST']}:3000" : "https://#{state['subdomain']}.#{get_domain}"
    end

    def xero_url
      "/api/v1/admin/onboarding_integrations/xero/authorize?#{URI.encode_www_form(params.to_h)}"
    end

    def smart_recruiters_url
      "/api/v1/admin/webhook_integrations/smart_recruiters/smart_recruiters_authorize?#{URI.encode_www_form(params.to_h)}"
    end

    def azure_ad_url
      state[:azure_login] ? azure_sso_url : azure_oauth_url
    end

    def azure_oauth_url
      "/api/v1/active_directory_authorize?#{URI.encode_www_form(params.to_h)}"
    end 

    def azure_sso_url
      "/omniauth/azure_oauth2/callback?#{URI.encode_www_form(params.to_h)}"
    end 

    def get_domain
      "#{ENV['DEFAULT_HOST']}#{'/hr' if ENV['IS_AZURE_INFRA'].present? }"
    end

    def invalid_request
      raise CanCan::AccessDenied 
    end
  end
end