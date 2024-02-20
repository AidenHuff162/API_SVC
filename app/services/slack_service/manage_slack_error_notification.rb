class SlackService::ManageSlackErrorNotification
  attr_reader :integration_name, :company_name, :action, :error
  
  def initialize(integration_name, company_name, action, error)
    @integration_name = integration_name
    @company_name = company_name
    @action = action
    @error = error
  end

  def perform
    fetch_active_webhooks.try(:each) { |slack_webhook| slack_webhook.send_notification(error[:message], "#{company_name} - #{error[:effected_profile]}") }
  end

  private
  def fetch_active_webhooks; IntegrationErrorSlackWebhook.filter_webhooks(integration_name, company_name, get_action) end

  def get_action
    if action.include?('Create')
      return 0
    end

    return -1
  end
end
