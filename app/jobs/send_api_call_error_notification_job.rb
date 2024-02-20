class SendApiCallErrorNotificationJob
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => false, :backtrace => true

  def perform(company_id, integration_name, action, status, response)
    company = Company.find_by(id: company_id)
    UserMailer.api_call_error_notification(company, integration_name, action, status, response).deliver_now!
  end
end
