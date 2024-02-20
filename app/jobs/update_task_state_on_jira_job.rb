class UpdateTaskStateOnJiraJob < ApplicationJob
  queue_as :default

  def perform(tuc_id)
    begin
      tuc = TaskUserConnection.find_by(id: tuc_id)
      return unless tuc.present?

      company = tuc.user.try(:company)
      return unless company.present?

      integration = Integration.find_by(company_id: company.id, api_name: 'jira')
      if tuc.jira_issue_id && integration && integration.client_secret && integration.secret_token && integration.jira_complete_status
        jira_client = get_jira_client(integration)
        issue = jira_client.Issue.find(tuc.jira_issue_id)
        completed_transition_id = get_jira_transition_id(jira_client, issue, integration.jira_complete_status)

        issue_transition = issue.transitions.build
        issue_transition.save!('transition' => {'id' => completed_transition_id}) if completed_transition_id != -1
        log(integration.company, 'Update', tuc.inspect, tuc.inspect, 200)
        integration.update_column(:last_sync, DateTime.now)
      end
    rescue Exception => e
      LoggingService::GeneralLogging.new.create(company, 'Update Task on Jira', {result: 'Failed to update', error: e.message, tuc: tuc.inspect })
      SlackNotificationJob.perform_later(company.id, {
        text: I18n.t('slack_notifications.jira_issue.updated', issue_id: tuc.jira_issue_id ,company_name: company.name )
      })
    end
  end

  private

  def get_jira_transition_id(jira_client, issue, status)
    completed_id = -1
    response = JSON.parse jira_client.get("#{jira_client.options[:rest_base_path]}/issue/#{issue.id}/transitions").body
    response["transitions"].each do |transition|
      completed_id = transition["id"] if transition["name"] == status
    end
    completed_id
  end

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
