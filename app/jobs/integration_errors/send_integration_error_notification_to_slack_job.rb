module IntegrationErrors
  class SendIntegrationErrorNotificationToSlackJob < ApplicationJob
    queue_as :manage_integration_error_notifications

    def perform(message, integration_type)
      # slack_webhooks = IntegrationErrorSlackWebhook.active_webhooks(integration_type) rescue []
      # slack_webhooks.try(:each) { |slack_webhook| slack_webhook.send_notification message }
    end
  end
end
