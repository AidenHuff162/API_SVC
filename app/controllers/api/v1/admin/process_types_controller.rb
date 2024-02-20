module Api
  module V1
    module Admin
      class ProcessTypesController < BaseController
      	# before_action :require_company!
        before_action :authenticate_user!
      	# before_action :verify_current_user_in_current_company!

      	# before_action only: [:index] do
       #    ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
       #  end
       #  rescue_from CanCan::AccessDenied do |exception|
       #    render body: Sapling::Application::EMPTY_BODY, status: 204 if params[:sub_tab].present?
       #  end

      	load_and_authorize_resource

        def index
          collection = ProcessTypesCollection.new(collection_params)
          respond_with collection.results
        end

        def create
 					@process_type.save 
          respond_with @process_type
        end

        private
        def collection_params
          params.merge(company_id: current_company.id, onboarding_plan: current_company.onboarding?)
        end
        def process_type_params
        	params.permit(:name, :company_id, :is_default, :entity_type)
        end
      end
    end
  end
end