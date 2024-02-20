class WebhookEvents::ExecuteWebhookEventJob
  include Sidekiq::Worker
  sidekiq_options :queue => :execute_webhook, :retry => 0, :backtrace => true
  
  def perform(company_id, event_id)
    WebhookEventServices::ExecuteEventService.new(company_id, event_id).perform
  end
end
