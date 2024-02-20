module Api
  module V1
    module Admin
      module OnboardingIntegrations
        class ActiveDirectoryController < ApiController
          before_action :require_company!
          # before_action :fetch_company, only: [:active_directory_authorize]
          before_action :initialize_application

          rescue_from CanCan::AccessDenied do |exception|          
            render body: Sapling::Application::EMPTY_BODY, status: 401
          end

          def new
            render json: {"url": @active_directory.authentication_request_url}
          end

          def active_directory_authorize
            response = @active_directory.authorize(params.to_h)
            
            if Rails.env.development?
              redirect_to "http://#{@current_company.app_domain}/#/admin/settings/integrations?map=adfs&response=#{response}" 
            else
              redirect_to "https://#{@current_company.app_domain}/#/admin/settings/integrations?map=adfs&response=#{response}" 
            end
          end

          private

          def fetch_company
            if params['state'].present?
              @current_company = Company.find_by(id: params['state'])
            end
          end

          def initialize_application
            @active_directory = SsoIntegrationsService::ActiveDirectory::AuthenticateApplication.new(@current_company)
          end
        end
      end
    end
  end
end