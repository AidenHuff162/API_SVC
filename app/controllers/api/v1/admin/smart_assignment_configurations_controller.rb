module Api
  module V1   
    module Admin 
      class SmartAssignmentConfigurationsController < ApiController
        before_action :require_company!

        before_action only: [:create, :get_sa_configuration] do
          ::PermissionService.new.checkAdminVisibility(current_user, 'groups')
        end

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        load_and_authorize_resource

        def create
          if @current_company&.smart_assignment_configuration
            @current_company.smart_assignment_configuration.update!(smart_assignment_configuration_params)
          else
            @smart_assignment_configuration.save!
          end
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def get_sa_configuration
          respond_with @current_company&.smart_assignment_configuration, serializer: SmartAssignmentConfigurationSerializer::Basic if @current_company&.smart_assignment_configuration
        end

        private

        def smart_assignment_configuration_params
          params.permit(meta: {}).merge!(company_id: current_company.id)
        end

      end
    end
  end
end