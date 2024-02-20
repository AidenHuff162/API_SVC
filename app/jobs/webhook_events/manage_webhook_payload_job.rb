class WebhookEvents::ManageWebhookPayloadJob
  include Sidekiq::Worker
  sidekiq_options :queue => :webhook_activities, :retry => 0, :backtrace => true

  def perform(company, event_data)
    return if company.nil?

    WebhooksPayloadManagement.new(company).webhook_payload_data(event_data['default_data_change'], event_data['user'], event_data['temp_user'], event_data['webhook_custom_field_data'], event_data['temp_profile'])
  end
end