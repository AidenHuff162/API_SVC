module Api
  module V1
    module Admin
      module OnboardingIntegrations
        class GustoController < ApiController
          before_action :require_company!, except: [:authorize]
          before_action :verify_state, only: [:authorize]
          before_action :initialize_application

          rescue_from CanCan::AccessDenied do |exception|          
            render body: Sapling::Application::EMPTY_BODY, status: 401
          end

          def authorize
            if params['error'] && params['error'] == 'access_denied'
              response = 'failure'
            else
              response = @gusto.authorize(params[:code])
            end
            
            if Rails.env.development?
              redirect_to "http://#{current_company.app_domain}/#/admin/settings/integrations?map=gusto&response=#{response}"
            else
              redirect_to "https://#{current_company.app_domain}/#/admin/settings/integrations?map=gusto&response=#{response}"
            end
          end

          private

          def initialize_application
            @gusto = HrisIntegrationsService::Gusto::AuthenticateApplication.new(current_company, @instance_id, @current_user_id)
          end
          
          def verify_state
            @current_company, @instance_id, @current_user_id = HrisIntegrationsService::Gusto::Helper.new.verify_state_and_fetch_company(params)
          end
        end
      end
    end
  end
end