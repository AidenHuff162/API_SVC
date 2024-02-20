class WebhookEvents::CreateOnboardingOffboardingWebhookEventsJob
  include Sidekiq::Worker
  sidekiq_options :queue => :webhook_activities, :retry => 0, :backtrace => true
  
  def perform(company_id, attributes)
    company = Company.find_by(id: company_id)
    return if company.nil?
    
    WebhookEventServices::CreateEventsService.new(company, attributes).perform
  end
end
