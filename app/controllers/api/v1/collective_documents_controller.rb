module Api
  module V1
    class CollectiveDocumentsController < ApiController
      before_action :require_company!
      before_action :authenticate_user!

      before_action only:  :paginated_documents do
        ::PermissionService.new.checkDocumentPlatformVisibility(current_user, params[:user_id] || current_user.id )
      end
      rescue_from CanCan::AccessDenied do |exception|
        render body: Sapling::Application::EMPTY_BODY, status: 204
      end

      def paginated_documents
        combined_documents_collection = CollectiveDocumentsCollection.new(paginated_params)
        results = combined_documents_collection.results

        render json: {
          draw: params[:draw].to_i,
          recordsTotal: combined_documents_collection.count,
          recordsFiltered: combined_documents_collection.count,
          data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: CombinedDocumentsSerializer::Full)
        }
      end

      private

      def paginated_params
        page = (params[:start].to_i / params[:length].to_i) + 1

        params.merge(
          company_id: current_company.id,
          page: page,
          per_page: params[:length].to_i,
          order_column: params[:order_column],
          order_in: params[:order_in],
          term: params[:term].empty? ? nil : params[:term]
        )
      end
    end
  end
end
