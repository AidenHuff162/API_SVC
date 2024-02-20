module Api
  module V1
    module Admin
      class HistoriesController < BaseController
        before_action :require_company!
        before_action :authenticate_user!
        before_action only: [:index] do
          ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
        end

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204 if params[:sub_tab].present?
        end

        load_and_authorize_resource except: [:index]
        authorize_resource only: [:index]

        def index
          collection = HistoriesCollection.new(collection_params)
          respond_with collection.results.order('created_at DESC'), each_serializer: HistorySerializer::Full, meta: {count: collection.count}, adapter: :json
        end

        def delete_scheduled_email
          History.delete_scheduled_email(@history) if @history.user_id?
          return render json: false
        end

        def update_scheduled_email
          History.update_scheduled_email(@history, params[:schedule_email_at]) if @history.user_id? && params[:schedule_email_at]
          return render json: false
        end

        private
        def collection_params
          params.merge(company_id: current_company.id)
        end
      end
    end
  end
end
