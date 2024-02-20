require 'reverse_markdown'
class UpdateTasksOnJiraJob < ApplicationJob
  queue_as :default

  def perform(task_id)
    task = Task.where(id: task_id, task_type: Task.task_types[:jira]).take
    return unless task.present?

    update_task_assigned_to_users(task)
  end

  private

  def update_task_assigned_to_users(task)
    integration = fetch_integration(task)
    return unless integration.present? && integration.client_secret.present? && integration.secret_token.present?

    task_user_connections = fetch_task_user_connections(task)
    return unless task_user_connections.present?

    update_tasks(task_user_connections, task, integration)
  end

  def fetch_task_user_connections(task)
    task.task_user_connections.where.not(jira_issue_id: nil)
  end

  def fetch_integration(task)
    task.workstream.company.integrations.find_by(api_name: 'jira')
  end

  def initialize_jira_client(integration)
    private_key_file_path = nil
    if !Rails.env.development? && !Rails.env.test?
      private_key_file = Tempfile.new(['private_key_file', '.pem'])
      private_key_file.binmode
      private_key_file.write open(integration.private_key_file.url).read
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

  def fetch_text_from_html(string)
    Nokogiri::HTML(string).xpath("//*[p]").first.content rescue " "
  end

  def build_data(task_user_connection, task, integration)
    task_name = fetch_text_from_html(ReplaceTokensService.new.replace_tokens(task.name, task_user_connection.user, nil, nil, nil, true)) if task.name.present?
    task_description = ''
    if task.description.present?
      task_description = ReverseMarkdown.convert(ReplaceTokensService.new.replace_tokens(task.description, task_user_connection.user, nil, nil, nil, true, nil, false).gsub(/<img.*?>/, "").gsub(/<iframe.*?iframe>/, ""), unknown_tags: :bypass) rescue ""
      task_description = task_description.gsub(/(\\)([><])/, '\2')
    end

    {
      "fields" => {
        "summary" => (task_name || '') + ' for ' + task_user_connection.user.full_name + ' [Sapling]',
        "description" => (task_description || ''),
        "project" => {
          "key" => integration.company_code
        }
      }
    }
  end

  def task_user_connection_to_string(task, task_user_connection)
    task_name = fetch_text_from_html(ReplaceTokensService.new.replace_tokens(task.name, task_user_connection.user, nil, nil, nil, true)) if task.name.present?
    task_description = fetch_text_from_html(ReplaceTokensService.new.replace_tokens(task.description, task_user_connection.user, nil, nil, nil, true, nil, false)) if task.description.present?

    "{name: #{(task_name || '')}, description: #{(task_description || '')}, id: #{task_user_connection.id}, user_id: #{task_user_connection.user_id}, task_id: #{task_user_connection.task_id}, state: #{task_user_connection.state}, created_at: #{task_user_connection.created_at}, updated_at: #{task_user_connection.updated_at}, owner_id: #{task_user_connection.owner_id}, due_date: #{task_user_connection.due_date}, jira_issue_id: #{task_user_connection.jira_issue_id} }"
  end

  def update_tasks(task_user_connections, task, integration)
    jira_client = initialize_jira_client(integration)

    task_user_connections.try(:find_each) do |task_user_connection|
      begin
        issue = jira_client.Issue.find(task_user_connection.jira_issue_id)
        if issue.present?
          data = build_data(task_user_connection, task, integration)
          issue.save!(data)
          log(integration.company, 'Update Name and Description - Success', task_user_connection_to_string(task, task_user_connection), data, 200)
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(integration.company)
        end
      rescue Exception => e
        log(integration.company, 'Update Name and Description - Failure', task_user_connection_to_string(task, task_user_connection), e.message, 500)
      end
    end
  end

  def log(company, action, request, response, status)
    LoggingService::IntegrationLogging.new.create(company, 'JIRA', action, request, response, status)
  end
end