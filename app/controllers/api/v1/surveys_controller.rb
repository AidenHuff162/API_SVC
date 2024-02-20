module Api
  module V1
    class SurveysController < BaseController

      def get_task_survey
        task_user_connection = TaskUserConnection.includes(task: [:workstream, survey: :survey_questions]).find_by(id: params[:task_user_connection_id])
        if task_user_connection.present? && task_user_connection.task&.survey_id && task_user_connection.owner_id == current_user.id && task_user_connection.task&.workstream&.company_id == current_company.id
          respond_with task_user_connection.task.survey, serializer: SurveySerializer::SurveyForm, scope: { task_user_connection_id: task_user_connection.id, task_user_connection_state: task_user_connection.state }
        else
          render body: Sapling::Application::EMPTY_BODY, status: 401
        end
      end

    end
  end
end
