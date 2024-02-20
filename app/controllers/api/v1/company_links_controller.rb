module Api
  module V1
    class CompanyLinksController < ApiController
      before_action :require_company!
      before_action :authenticate_user!

      def index
      	collection = CompanyLinksCollection.new(company_links_params)
        if params[:updates_page]
          respond_with collection.results.order('position ASC'), each_serializer: CompanyLinkSerializer::UpdatesPage, meta: {count: collection.count}, adapter: :json
        else
          respond_with collection.results.order('position ASC'), each_serializer: CompanyLinkSerializer::Full, meta: {count: collection.count}, adapter: :json
        end
      end

      private

      def company_links_params
        params.merge!(company: current_company)
      end
    end
  end
end
