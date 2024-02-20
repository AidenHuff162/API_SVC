class FeedbackSerializer < ActiveModel::Serializer
  attributes :company_id, :user_id, :module, :like
end
