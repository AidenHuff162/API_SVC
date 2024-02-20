module Api
  module V1
    module Admin
      class IntegrationInstancesController < ApiController
        before_action :require_company!
        before_action :authenticate_user!
        load_and_authorize_resource only: [:create, :show, :update, :destroy, :authorize]
        authorize_resource only: [:index, :destroy_instance_by_inventory, :sync_now, :get_credentials]

        rescue_from CanCan::AccessDenied do |exception|          
          render body: Sapling::Application::EMPTY_BODY, status: 401
        end

        def index
          respond_with IntegrationInventory.active_inventories, each_serializer: IntegrationInstanceSerializer::Full, company: current_company
        end

        def show
          respond_with @integration_instance, serializer: IntegrationInstanceSerializer::Full, company: current_company
        end

        def create
          @integration_instance.save!
          respond_with @integration_instance, serializer: IntegrationInstanceSerializer::Basic, company: current_company
        end

        def update
          @integration_instance.update!(integration_instance_params)
          respond_with @integration_instance, serializer: IntegrationInstanceSerializer::Basic, company: current_company
        end

        def destroy
          @integration_instance.destroy!
          render :json => {status: 200}
        end

        def destroy_instance_by_inventory
          current_company.integration_instances.where(integration_inventory_id: params[:inventory_id]).destroy_all
          render :json => {status: 200}
        end

        def sync_now
          IntegrationsService::UserIntegrationOperationsService.new(current_user).perform('sync', params[:inventory_id]) if params[:inventory_id]
        end

        def authorize
          render json: @integration_instance.callback_url(current_user.id, request.host)
        end

        def create_account
          render json: IntegrationsService::UserIntegrationOperationsService.new(current_user).perform('create_account', params[:api_identifier])
        end

        def get_credentials
          result = {}
          type = params[:type]
          result[:key] = client_credentials(type)
          respond_with result.to_json
        end

        private

        def client_credentials(type)
          IntegrationInstance.generate_client_credentials(current_company, type)
        end

        def integration_instance_params
          if params[:integration_field_mappings].present?
            params.merge!(integration_credentials_attributes: (params[:integration_credentials] || [{}]), integration_field_mappings_attributes: (params[:integration_field_mappings].map { |cred| cred.merge!(company_id: current_company.id) } || [{}]), company_id: current_company.id).permit(:id, :company_id, :integration_inventory_id, :api_identifier, :_destroy, :state, :name, filters: [location_id: [], team_id: [], employee_type: []], integration_credentials_attributes: [:id, :integration_configuration_id, :value, :name, {selected_options: []}], integration_field_mappings_attributes: [:id, :is_custom, :custom_field_id, :preference_field_id, :integration_field_key, :company_id, :field_position, integration_selected_option: [:id, :name, :section]])
          else
            params.merge!(integration_credentials_attributes: (params[:integration_credentials] || [{}]), company_id: current_company.id).permit(:id, :company_id, :integration_inventory_id, :api_identifier, :_destroy, :state, :name, filters: [location_id: [], team_id: [], employee_type: []], integration_credentials_attributes: [:id, :integration_configuration_id, :value, :name, {selected_options: []}])
          end
        end
      end
    end
  end
end
