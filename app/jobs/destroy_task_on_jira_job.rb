class DestroyTaskOnJiraJob < ApplicationJob
  queue_as :default

  def perform(issue_id, company_id)
    integration = Integration.find_by(company_id: company_id, api_name: 'jira')
    return unless integration.present?

    begin
      if issue_id && integration && integration.client_secret && integration.secret_token
        jira_client = get_jira_client(integration)
        issue = jira_client.Issue.find(issue_id)
        issue.delete if issue
        log(integration.company, 'Delete', issue ? issue.inspect : nil, 'Done', 200)
        integration.update_column(:last_sync, DateTime.now)
      end
    rescue Exception => e
      log(integration.company, 'Delete', nil, e.message, 500)
      SlackNotificationJob.perform_later(company_id, {
        text: I18n.t('slack_notifications.jira_issue.deleted', issue_id: issue_id ,company_name: integration.company.name )
      })
    end
  end

  private

  def get_jira_client(integration)
    private_key_file_path = nil
    if !Rails.env.development? && !Rails.env.test?
      private_key_file = Tempfile.new(['private_key_file', '.pem'])
      private_key_file.binmode
      retries ||= 0
      begin
        private_key_file.write open(integration.private_key_file.url).read
      rescue Net::OpenTimeout, Net::ReadTimeout
        retry if (retries += 1) < 3
      end
      private_key_file.rewind
      private_key_file.close
      private_key_file_path = private_key_file.path
    else
      private_key_file_path = "public" + integration.private_key_file.url
    end

    options = {
      private_key_file: private_key_file_path,
      consumer_key: integration.client_id,
      context_path: '',
      site: integration.channel
    }
    jira_client = JIRA::Client.new(options)
    jira_client.set_access_token(integration.secret_token, integration.client_secret)

    jira_client
  end

  def log(company, action, request, response, status)
    LoggingService::IntegrationLogging.new.create(company, 'JIRA', action, request, response, status)
  end
end
