class WebhookEvents::CreateKeyDateReachedWebhhokEventsForCompanyJob
  include Sidekiq::Worker
  sidekiq_options :queue => :webhook_activities, :retry => 0, :backtrace => true
  
  def perform(company_id)
    company = Company.find_by(id: company_id)
    return if company.nil?
    
    WebhookEventServices::CreateKeyDateReachedEventsService.new(company).perform
  end
end
