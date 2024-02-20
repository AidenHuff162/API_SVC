module Api
  module V1
    class SurveyAnswersController < BaseController
      load_and_authorize_resource

      def create
        @survey_answer.save!
        head 200
      end

      private

      def survey_answer_params
        params.permit(:task_user_connection_id, :survey_question_id, :value_text, selected_user_ids: [])
      end

    end
  end
end
