class SlackNotificationJob < ApplicationJob
  queue_as :slack_notification

  def perform(company_id=nil, message_payload=nil)
    if company_id.present?
      slack = IntegrationInstance.find_by(api_identifier: "slack_communication", company_id: company_id, state: :active) rescue nil
      if slack.present? && slack.webhook_url.present? && slack.channel.present?
        payload = {"channel" => slack.channel}
        if message_payload.present?
          begin
            payload.merge!(message_payload)
            RestClient.post slack.webhook_url, payload.to_json, {content_type: :json, accept: :json}
          rescue
            puts '----------SlackNotificationJob Exception -------------'
            puts company_id
          end
        end
      end
    end
  end
end
