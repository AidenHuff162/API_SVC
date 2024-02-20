module SurveySerializer
  class Base < ActiveModel::Serializer
    attributes :id, :survey_type, :name, :estimated_time
    has_many :survey_questions, serializer: SurveyQuestionSerializer::Base

  end
end
