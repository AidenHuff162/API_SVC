class RecommendationFeedbackForm < BaseForm
  attribute :changeReason, Integer
  attribute :processType, Integer
  attribute :itemAction, Integer
  attribute :userSuggestion, String
  attribute :recommendedItems, Array[Integer]
  attribute :updatedItems, Array[Integer]
  attribute :recommendation_user_id
end
