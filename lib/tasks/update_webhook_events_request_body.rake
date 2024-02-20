namespace :webhook_event do

  desc "updated webhook events"
  task updated_webhook_events: :environment do
    webhook_events = WebhookEvent.where.not(request_body: nil)
    webhook_events.find_each do |event|
      request_body = event.request_body.except('webhook_event')
      if request_body.present?
        webhook_event = event.request_body['webhook_event']
        event.update(request_body: { "webhook_event" => webhook_event.merge(request_body)})
      end
    end
    puts "Task completed"
  end
end
