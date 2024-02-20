module Api
  module V1
    class CustomTablesController < ApiController
      before_action :require_company!
      before_action :authenticate_user!
      before_action only: [:home_index] do
        ::PermissionService.new.checkTableVisibility(current_user, params[:user_id] || current_user.id )
        authorize_user if params[:user_id]
      end
      load_and_authorize_resource except: [:home_index]
      authorize_resource only: [:home_index]
      rescue_from CanCan::AccessDenied do |exception|
        head 204
      end

      def home_index
        collection = CustomTablesCollection.new(home_index_page_collection_params)
        respond_with collection.results, each_serializer: CustomTableSerializer::CustomTableForInfo, user_id: params[:user_id], include: '**'
      end

      private

      def home_index_page_collection_params
        params.merge(company_id: current_company.id, custom_table_ids: PermissionService.new.fetch_accessable_custom_tables(current_company, current_user, params[:user_id]), is_home_page: true, enable_custom_table_approval_engine: current_company.enable_custom_table_approval_engine)
      end
    end
  end
end
