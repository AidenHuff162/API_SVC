module WebhookHandler
  extend ActiveSupport::Concern

  def send_updates_to_webhooks(current_company, event_data)
    WebhookEventServices::ManageWebhookEventService.new.initialize_event(current_company, event_data)
  end
end
