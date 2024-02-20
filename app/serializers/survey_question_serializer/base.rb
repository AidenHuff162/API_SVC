module SurveyQuestionSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :question_type, :position, :question_text, :survey_id

  end
end
