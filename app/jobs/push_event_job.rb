class PushEventJob < ApplicationJob

  def perform(event_name, user, metadata)
    Interactions::Tracking::Event.new(event_name, user, metadata).perform if ENV['INTERCOM_APP_ID'] && ENV['INTERCOM_API_KEY']
  end
end
