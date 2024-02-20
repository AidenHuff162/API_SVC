module Api
  module V1
    module Admin
      module OnboardingIntegrations
        class DeputyController < ApiController
          before_action :require_company!
          before_action :initialize_application

          rescue_from CanCan::AccessDenied do |exception|          
            render body: Sapling::Application::EMPTY_BODY, status: 401
          end

          def new
            render json: @deputy.authentication_request_url
          end

          def authorize
            response = @deputy.authorize(params[:code])
            redirect_to "https://#{current_company.app_domain}/#/admin/settings/integrations?map=deputy&response=#{response}"
          end

          private

          def initialize_application
            @deputy = HrisIntegrationsService::Deputy::AuthenticateApplication.new(current_company)
          end
        end
      end
    end
  end
end