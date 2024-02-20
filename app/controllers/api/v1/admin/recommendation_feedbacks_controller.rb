module Api
  module V1
    module Admin
      class RecommendationFeedbacksController < BaseController
        load_and_authorize_resource

        def create
          @recommendation_feedback.save!
          respond_with @recommendation_feedback, serializer: RecommendationFeedbackSerializer::Base
        end

        def recommendation_feedback_params
          params.permit(:recommendation_user_id, :processType, :itemType, :changeReason, :userSuggestion, :itemAction, :recommendedItems => [], :updatedItems => []).merge(recommendation_owner_id: current_user.id)
        end
      end
    end
  end
end
