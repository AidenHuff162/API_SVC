module Api
  module V1
    class EmailTemplatesController < ApiController
      load_and_authorize_resource

      def index
        collection = EmailTemplatesCollection.new(collection_params)
        user = current_company.users.find_by(id: params[:user_id])        
        if collection_params[:email_type] == "offboarding"
          user.termination_type = params[:termination_type]
          user.eligible_for_rehire = params[:eligible_for_rehire]
          user.last_day_worked = params[:last_day_worked]
          user.termination_date = params[:termination_date]
        end
        respond_with collection.results, each_serializer: InboxSerializer::Simple, scope: {user: user}
      end

      private

      def collection_params
        params.merge(company_id: current_company.id)
      end
    end
  end
end
