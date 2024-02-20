class WebhookEvents::CreateJobDetailsChangedWebhookEventsJob
  include Sidekiq::Worker
  sidekiq_options :queue => :webhook_activities, :retry => 0, :backtrace => true
  
  def perform(company_id, user_attributes, params, data, table_name, effective_date)
    company = Company.find_by(id: company_id)
    return if company.nil?
    
    WebhookEventServices::CreateJobDetailsChangedEventsService.new(company, user_attributes, params, data, table_name, effective_date).perform
  end
end
