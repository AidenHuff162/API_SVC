class IntegrationErrorSlackWebhook < ApplicationRecord
	enum status: { active: 0, inactive: 1 }
  enum integration_type: { human_resource_information_system: 0, applicant_tracking_system: 1, issue_and_project_tracker: 2 }
  enum configure_app: { slack: 0, teams: 1 }

  scope :active_webhooks, -> (integration_type) { active.send("#{integration_type}") }
  scope :by_name, -> (integration_name) { where(integration_name: integration_name) }
  scope :active, -> () { where(status: IntegrationErrorSlackWebhook.statuses[:active]) }
  scope :by_company_name, -> (company_name) { where(company_name: [company_name, '', nil]) }
  scope :by_event_type, -> (event_type) { where(event_type: [event_type, '', nil]) }

  def is_slack_initialized?
    !webhook_url.blank? && !channel.blank?
  end

   def is_team_initialized?
    !webhook_url.blank?
  end

  def is_app_configured?
    (self.slack? && self.is_slack_initialized?) || (self.teams? && is_team_initialized?)
  end

  def self.filter_webhooks(integration_name, company_name, event_type)
    by_name(integration_name).active.by_company_name(company_name).by_event_type(event_type)
  end

  def send_notification(message, username=nil)
    return unless self.is_app_configured?

    begin
      payload = prepare_payload(message, username)
      RestClient.post webhook_url, payload.to_json, {content_type: :json, accept: :json}
    rescue Exception => e
      puts "=================IntegrationErrorSlackWebhook: #{e.inspect} =================="
    end
  end

  private

  def prepare_payload(message, username)
    payload = case self.configure_app
              when 'slack'
                { username: username || 'Sapling', text: message, channel: channel}
              when 'teams'
                TeamService::BuildPayload.new.prepare_payload(message, 'Integration errors', username || 'Sapling')
              end
  end
end
