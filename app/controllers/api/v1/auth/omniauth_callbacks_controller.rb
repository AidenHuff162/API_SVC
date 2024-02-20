module Api
  module V1
    module Auth
      class OmniauthCallbacksController < ::DeviseTokenAuth::OmniauthCallbacksController
        include SAMLSettings
        before_action :require_company!, only: [:omniauth_success, :redirect_callbacks, :omniauth_failure, :consume_saml_response]

        attr_reader :auth_params
        skip_before_action :set_user_by_token, raise: false
        skip_after_action :update_auth_header, raise: false

        def redirect_callbacks
          # before authentication.

          devise_mapping = get_devise_mapping
          redirect_route = get_redirect_route(devise_mapping)
          # auth response to avoid CookieOverflow.
          session['dta.omniauth.auth'] = request.env['omniauth.auth'].except('extra')
          session['dta.omniauth.auth'] = request.env['omniauth.auth'].except('credentials') if request.env['omniauth.auth'].provider.present? && request.env['omniauth.auth'].provider == "azure_oauth2" 
          session['dta.omniauth.params'] = request.env['omniauth.params']
          redirect_to redirect_route
        end

        def consume_saml_response
          @auth_params = {}
          if check_for_saml_credentials

            # Logging.create!(company_id: current_company.id, action: "Saml credentials present", api_request: "None", integration_name: "SSO", result: {company: current_company.inspect, params: params}, state: 200)
            if current_company.id == 37 
              response = OneLogin::RubySaml::Response.new(params[:SAMLResponse], settings: saml_shib_settings)
              @resource = response.is_valid? ? SsoIntegrationsService::Shibboleth::UCSF::FetchUserByResponse.new(response, current_company).perform : nil rescue nil
            elsif current_company.subdomain == 'hci'
              response = OneLogin::RubySaml::Response.new(params[:SAMLResponse], settings: saml_shib_settings)
              @resource = response.is_valid? ? User.from_saml_response(response, current_company) : nil rescue nil
              name_id = response.name_id rescue nil
              Logging.create(company_id: current_company.id, action: "Shibboleth HCI", api_request: "None", integration_name: "SSO", result: {name_id: name_id, nameid: response.nameid, response: response.inspect, resource: @resource, is_valid: response.is_valid?, errors: response.errors}, state: 200)
            elsif current_company.subdomain == 'martinagency'
              # Logging.create!(company_id: current_company.id, action: "Martin Agency present", api_request: "None", integration_name: "SSO", result: {company: current_company.inspect, params: params}, state: 200)
              response = OneLogin::RubySaml::Response.new(params[:SAMLResponse], {allowed_clock_drift: 5.second, skip_subject_confirmation: true, settings: saml_martin_settings})

              @resource = response.is_valid? ? User.from_saml_response(response, current_company) : nil rescue nil

              # Logging.create!(company_id: current_company.id, action: "Resource present", api_request: "None", integration_name: "SSO", result: {resource: @resource, is_valid: response.is_valid?, errors: response.errors}, state: 200)
            else
              response = OneLogin::RubySaml::Response.new(params[:SAMLResponse])
              response.settings = saml_settings
              # Logging.create!(company_id: current_company.id, action: "Response present", api_request: "None", integration_name: "SSO", result: {params: params, response: response.inspect}, state: 200) rescue nil
              if current_company.subdomain == 'statestitle' #need to remove this condition once the data will be migrated for statestitle
                # Logging.create!(company_id: current_company.id, action: "Statestitle Resource present", api_request: "None", integration_name: "SSO", result: {nameid: response.nameid.downcase}, state: 200) rescue nil
                @resource = response.is_valid? && response.nameid.downcase.present? ? current_company.users.where("lower(temporary_email) = ? OR lower(email) = ?", response.nameid.downcase, response.nameid.downcase).first : nil rescue nil
              else
                @resource = response.is_valid? ? User.from_saml_response(response, current_company) : nil rescue nil
              end
            end

            if @resource.present? && @resource.class.name == 'User'
              # Logging.create!(company_id: current_company.id, action: "User Is Valid", api_request: "None", integration_name: "SSO", result: {resource: @resource}, state: 200)
              sign_out(@resource)
              set_token_on_resource
              auth_params = create_auth_params
              sign_in(:user, @resource, store: false, bypass: false)
              one_login_integration = current_company.integration_instances.find_by(api_identifier: "one_login", state: :active)
              one_login_integration.update_column(:synced_at, DateTime.now) if one_login_integration
              okta_integration = current_company.integration_instances.find_by(api_identifier: "okta", state: :active)
              okta_integration.update_column(:synced_at, DateTime.now) if okta_integration
              adfs_integration = current_company.integration_instances.find_by(api_identifier: "active_directory_federation_services", state: :active)
              adfs_integration.update_column(:synced_at, DateTime.now) if adfs_integration
              ping_id_integration = current_company.integration_instances.find_by(api_identifier: "ping_id", state: :active)
              ping_id_integration.update_column(:synced_at, DateTime.now) if ping_id_integration
              shib_integration = current_company.integration_instances.find_by(api_identifier: "shibboleth", state: :active)
              shib_integration.update_column(:synced_at, DateTime.now) if shib_integration
              yield @resource if block_given?
              auth_params = auth_params.stringify_keys
              if params["RelayState"].present? and params["RelayState"] != "https://#{current_company.app_domain}/"
                redirect_to generate_url(params["RelayState"], auth_params)
              else
                redirect_to generate_url("https://#{current_company.app_domain}/#/login", auth_params).gsub("http:", "https:")
              end
            else
              if @resource.present?
                # Logging.create!(company_id: current_company.id, action: "Invalid Resource Present", api_request: "None", integration_name: "SSO", result: {resource: @resource}, state: 500)
                error_params = { error: 'user_does_not_exist', error_message: @resource }
                create_integration_logging({response: @resource, saml_response: response.inspect}, 404)
              else
                # Logging.create!(company_id: current_company.id, action: "Resource Not Present", api_request: "None", integration_name: "SSO", result: {resource: @resource}, state: 500)
                error_params = { error: 'user_does_not_exist', error_message: I18n.t('errors.user_does_not_exist').to_s }
                create_integration_logging({response: I18n.t('errors.user_does_not_exist').to_s, saml_response: response.inspect}, 404)
              end

              redirect_to generate_url("https://#{current_company.app_domain}/#/login", error_params)
            end
          else
            create_integration_logging({response: "missing configs", saml_response: response.inspect}, 500)
            error_params = { error: 'user_does_not_exist', error_message: I18n.t('errors.missing_configuration').to_s }
            redirect_to generate_url("https://#{current_company.app_domain}/#/login", error_params)
          end
        end

        def omniauth_success
          provider = auth_hash['provider'] rescue nil
          @resource = {}
          @auth_params = {}
          if google_provider?(provider) || azure_provider?(provider)
            Logging.create!(company_id: current_company.id, action: "Saml credentials present", api_request: "None", integration_name: "SSO", result: {auth_hash: auth_hash.inspect}, state: 200)
            if current_company.subdomain == 'statestitle' #need to remove this condition once the data will be migrated for statestitle
              user_email = auth_hash['info']['email'].downcase rescue nil
              @resource = resource_class.where("company_id = ? AND ( lower(temporary_email) = ? OR lower(email) = ? )", current_company.id, user_email, user_email).first if user_email.present?
            else
              get_resource_from_auth_hash
            end

            if @resource.present? && !user_offboarded?
              set_token_on_resource
              create_auth_params

              if resource_class.devise_modules.include?(:confirmable)
                @resource.skip_confirmation!
              end
              sign_in(:user, @resource, store: false, bypass: false)
              @resource.save!
              yield @resource if block_given?
            end
          end
          render_data_or_redirect('deliverCredentials', @auth_params.as_json, @resource.as_json, provider)
        end

        protected

        def get_resource_from_auth_hash
          @resource = resource_class.where({
            company_id: current_company.id,
            email: auth_hash['info']['email'].downcase
          }).first if (auth_hash['info']['email'].present? rescue nil)
          @resource
        end

        def render_data_or_redirect(message, data, user_data = {}, provider)
          if ['inAppBrowser', 'newWindow'].include?(omniauth_window_type)
            render_data(message, user_data.merge(data))
          elsif auth_origin_url
            data = { error: 'user_does_not_exist', error_message: I18n.t("errors.#{provider.split('_').first}_user_does_not_exist")} if user_data.nil? || user_data.empty?
            redirect_to generate_url(auth_origin_url, data)
          else
            fallback_render data[:error] || 'An error occurred'
          end
        end

        def generate_url(url, params = {})
          if url.scan("#").count > 1
            url_parts = url.split("#")
            url_without_fragment = url_parts[0] + "#" + url_parts[1]
            url_fragment = "##{url_parts[2]}"
            uri = URI(url_without_fragment)
          else
            uri = URI(url)
            url_fragment = "##{uri.fragment}" if uri.fragment
          end
          res = "#{uri.scheme}://#{uri.host}"
          res += ":#{uri.port}" if (uri.port and uri.port != 80 and uri.port != 443)
          res += "#{uri.path}" if uri.path
          query = [uri.query, params.to_query].reject(&:blank?).join('&')
          if url_fragment.present?
            url_fragment = url_fragment.split('?')[0]
            res += url_fragment
          end

          unless params.key?(:error)
            query = query.present? ? "#{query}&sapling_auth=true" : "sapling_auth=true"
          end
          res += "?#{query}"

          return res
        end

        private

        def check_for_saml_credentials
          (saml_settings.idp_sso_target_url.present? and saml_settings.idp_cert.present?) || (current_company.authentication_type == 'active_directory_federation_services' and saml_settings.idp_cert.present?)
        end

        def current_company
          @current_company ||= request.env['CURRENT_COMPANY']
        end

        def user_offboarded?
          @resource.state.eql?("inactive") || @resource.current_stage.eql?(User.current_stages[:departed])
        end

        def require_company!
          raise ActiveRecord::RecordNotFound unless current_company
        end

        def google_provider?(provider)
          provider.eql?("google_oauth2")
        end

        def azure_provider?(provider)
          provider.eql?("azure_oauth2")
        end

        def create_integration_logging(response, status)
          @integration_logging ||= LoggingService::IntegrationLogging.new
          @integration_logging.create(current_company, 'SAML', 'SAML Login', 'SAML login', response, status)
        end
      end
    end
  end
end
