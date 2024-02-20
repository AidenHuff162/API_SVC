module Api
  module V1
    module Admin
      class RequestInformationsController < BaseController
        load_and_authorize_resource

        before_action only: [:bulk_request] do
          raise CanCan::AccessDenied if current_user.role != "account_owner" && !current_user.is_admin_with_view_and_edit_people_page?
        end

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 403
        end

        def create
          @request_information.save!
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        def bulk_request
          BulkRequestInformationJob.perform_async(params[:user_ids], current_user.id, current_company.id, params[:profile_field_ids])
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        private

        def request_information_params
          params[:profile_field_ids] ||= []
          params.merge!(company_id: current_company.id, requester_id: current_user.id).permit(:company_id, :requester_id, :requested_to_id,
            :profile_field_ids => [])
        end

        def bulk_request_params
          params[:profile_field_ids] ||= []
          params.merge!(company_id: current_company.id, requester_id: current_user.id).permit(:company_id, :requester_id, :user_ids,
            :profile_field_ids => [])
        end
      end
    end
  end
end
