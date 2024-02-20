module Api
  module V1
    module Admin
      class FeedbacksController < BaseController
        before_action :authenticate_user!

        def index
          collection = FeedbacksCollection.new(query_params)
          respond_with collection.results, each_serializer: FeedbackSerializer
        end

        def create
          feedback = Feedback.new(create_params)
          feedback.save!
          respond_with feedback, serializer: FeedbackSerializer
        end

        private

        def create_params
          params.permit(:module, :like).merge!(user_id: current_user.id, company_id: current_company.id)
        end

        def query_params
          params.permit(:module).merge!(user_id: current_user.id, company_id: current_company.id)
        end
      end
    end
  end
end
