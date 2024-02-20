module Api
  module V1
    module Admin
      class IntegrationInventoriesController < ApiController
        before_action :require_company!
        load_and_authorize_resource only: [:show]
        authorize_resource only: [:index]

        rescue_from CanCan::AccessDenied do |exception|          
          render body: Sapling::Application::EMPTY_BODY, status: 401
        end

        def index
          respond_with IntegrationInventory.active_inventories, each_serializer: IntegrationInventorySerializer::Basic, current_company: current_company
        end

        def show
          instances = IntegrationInstance.by_inventory(@integration_inventory.id, current_company.id).includes(:connected_by)
          respond_with @integration_inventory, serializer: IntegrationInventorySerializer::Full, current_company: current_company, instances: instances
        end
      end
    end
  end
end