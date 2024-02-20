module RecommendationFeedbackSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :recommendation_user_id, :recommendation_owner_id, :itemType, :processType, :itemAction, :recommendedItems, :updatedItems, :changeReason, :userSuggestion
  end
end
