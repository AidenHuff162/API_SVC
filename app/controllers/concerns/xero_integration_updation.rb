module XeroIntegrationUpdation
  extend ActiveSupport::Concern

  def send_to_xero_integration user, params
    SendUpdatedEmployeeToXeroJob.perform_later(user, ["first_name", "last_name"]) if (params[:first_name] || params[:last_name]) && (user.first_name != params[:first_name] || user.last_name != params[:last_name])
    SendUpdatedEmployeeToXeroJob.perform_later(user, ["start_date"]) if params[:start_date] && params[:start_date].to_date.strftime("%Y-%m-%d") != user.start_date.to_s
    SendUpdatedEmployeeToXeroJob.perform_later(user, ['title']) if params[:title] && user.title != params[:title]
    SendUpdatedEmployeeToXeroJob.perform_later(user, ["personal_email"]) if params[:personal_email] && user.personal_email != params[:personal_email]
  end
end
