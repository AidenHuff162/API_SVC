class WebhookEvents::CreateProfileChangedWebhookEventsJob
  include Sidekiq::Worker
  sidekiq_options :queue => :webhook_activities, :retry => 0, :backtrace => true
  
  def perform(company_id, user_attributes, params, profile_update=false)
    company = Company.find_by(id: company_id)
    return if company.nil?
    
    WebhookEventServices::CreateProfileChangedEventsService.new(company, user_attributes, params, profile_update).perform
  end
end
