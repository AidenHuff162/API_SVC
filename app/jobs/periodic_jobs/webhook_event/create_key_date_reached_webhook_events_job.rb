module PeriodicJobs::WebhookEvent
  class CreateKeyDateReachedWebhookEventsJob
    include Sidekiq::Worker
    
    def perform
      company_ids = Company.joins(:webhooks).where(webhooks: {state: :active, event: Webhook.events['key_date_reached']},
       time_zone: ActiveSupport::TimeZone.all.map { |time| time.name if time.now.hour ==  0 }.compact).pluck(:id).uniq
      return if company_ids.blank?
      
      Company.where(id: company_ids).each { |company| WebhookEventServices::ManageWebhookEventService.new.initialize_event(company, {event_type: 'key_date_reached' }) }
    end
  end
end
