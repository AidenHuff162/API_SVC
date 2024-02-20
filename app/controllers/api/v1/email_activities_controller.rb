module Api
  module V1
    class EmailActivitiesController < ApiController
      before_action :require_company!

      def index
        company_id = current_company.id
        params[:task].each do |token|
          tuc = TaskUserConnection.find_by_sql(["select task_user_connections.* from task_user_connections inner join users on users.id = task_user_connections.user_id inner join companies on companies.id = users.company_id AND companies.id = ? AND task_user_connections.token = ?", company_id, token])
          tuc.first.update(state: :completed, completed_by_method: TaskUserConnection.completed_by_methods[:email]) if tuc.first.present? && !tuc.first.task.try(:survey_id)
        end if params[:task]

        if params[:task].present?
          redirect_to "https://#{current_company.app_domain}/#/activities_completed"
        else
          redirect_to "https://#{current_company.app_domain}/#/updates"
        end
      end
    end
  end
end
