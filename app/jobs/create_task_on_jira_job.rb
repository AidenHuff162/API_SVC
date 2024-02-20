require 'reverse_markdown'
class CreateTaskOnJiraJob
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => true, :backtrace => true

  def perform(user_id, task_user_connection_ids)
    begin
      return unless task_user_connection_ids.present?
      puts '-----------------jira job started--------------'
      user = User.find_by(id: user_id)
      task_user_connections = TaskUserConnection.where('id IN (?) AND user_id = ? AND jira_issue_id IS NULL', task_user_connection_ids, user_id)
      @jira_client = nil
      if user
        integration = Integration.find_by(company_id: user.company_id, api_name: 'jira')
        tasks_count = 0
        task_user_connections.each do |tuc|
          if tuc.task.task_type == 'jira'
            if tuc.before_due_date == nil || (tuc.before_due_date.in_time_zone(user.company.time_zone) < Time.now)
              tasks_count += create_jira_issue(tuc, integration, user)
            else
              # if task is to be assigned later, reschedule this job for its assignment date
              CreateTaskOnJiraJob.perform_at(tuc.before_due_date.in_time_zone(user.company.time_zone), user.id, tuc.id)
            end
          end
        end if integration && integration.client_secret && integration.secret_token

        send_notifications(user, tasks_count) if tasks_count > 0
        integration.update_column(:last_sync, DateTime.now) if integration
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(user.company)

        puts '----------------------------------'
        puts '-------JIRA Issues created--------'
        puts '----------------------------------'
      end
    rescue Exception => e
      puts '--------------------------------------'
      puts e.inspect
      puts '--------------------------------------'
      SlackNotificationJob.perform_later(user.company.id, {
        username: user.full_name,
        text: I18n.t('slack_notifications.jira_issue.created', company_name: user.company.name, full_name: user.full_name )
      }) if user
      log(user.company, 'Create', {user_id: user_id, tucs: task_user_connection_ids.inspect}, {message: e.message}, 500)
    end
  end

  private

  def send_notifications(user, tasks_count)
    history_description = I18n.t('history_notifications.jira.created',
                                  task_count: tasks_count,
                                  full_name: user.full_name,
                                  current_stage: user.current_stage)
    @private_key_file.unlink if @private_key_file.present?

    History.create_history({
      company: user.company,
      description: history_description,
      attached_users: [user.id],
      created_by: History.created_bies[:system],
      integration_type: History.integration_types[:jira],
      event_type: History.event_types[:integration]
    })
  end

  def create_jira_issue(tuc, integration, user)
    begin
      @jira_client ||= get_jira_client(integration)
      issue = @jira_client.Issue.build


      if issue.save get_issue_data(tuc, integration, user)
        issue.fetch
        tuc.jira_issue_id = issue.id
        tuc.save!
        log(integration.company, 'Create', task_user_connection_to_string(tuc), 'Done', 200)
        1
      elsif issue.try(:errors)
        log(integration.company, 'Create', task_user_connection_to_string(tuc), issue.errors, 500)
        SlackNotificationJob.perform_later(user.company.id, {
          username: user.full_name,
          text: I18n.t('slack_notifications.jira_issue.created', company_name: user.company.name , full_name: user.full_name)
        }) if user
        0
      elsif issue.present?
        puts "Issue not created"
        puts "------------ @private_key_file.try(:path) -------------"
        data = "Errors #{ issue.inspect}"
        log(integration.company, 'Create', task_user_connection_to_string(tuc), data, 500)
      end

    rescue Exception => e
      puts '-------------------------------'
      puts e
      puts '-------------------------------'
      log(integration.company, 'Create', task_user_connection_to_string(tuc), {error: issue.try(:errors), message: e.message}, 500)
      SlackNotificationJob.perform_later(user.company.id, {
          username: user.full_name,
          text: I18n.t('slack_notifications.jira_issue.created', company_name: user.company.name , full_name: user.full_name)
        }) if user
      0
    end
  end

  def task_user_connection_to_string tuc
    "{id: #{tuc.id}, user_id: #{tuc.user_id}, task_id: #{tuc.task_id}, state: #{tuc.state}, created_at: #{tuc.created_at}, updated_at: #{tuc.updated_at}, owner_id: #{tuc.owner_id}, due_date: #{tuc.due_date}, jira_issue_id: #{tuc.jira_issue_id} }"
  end

  def get_issue_data(tuc, integration, user)
    tuc.task.name = fetch_text_from_html(ReplaceTokensService.new.replace_tokens(tuc.task.name, user, nil, nil, nil, true)) if tuc.task.name
    task_description = ''
    if tuc.task.description
      task_description = ReverseMarkdown.convert(ReplaceTokensService.new.replace_tokens(tuc.task.description, user, nil, nil, nil, true, nil, false).gsub(/<img.*?>/, "").gsub(/<iframe.*?iframe>/, ""), unknown_tags: :bypass) rescue ""
      task_description = task_description.gsub(/(\\)([><])/, '\2')
    end

    {
      "fields"=>
      {
        "summary"=> (tuc.task.name || "") + " for " + tuc.user.full_name + " [Sapling]",
        "description"=>task_description,
        "project"=>
        {
          "key"=>integration.company_code
        },
        "issuetype"=>
        {
          "name"=>integration.jira_issue_type
        },
        "duedate" => "#{tuc.due_date.strftime('%Y-%m-%d')}"
      }
    }
  end

  def get_jira_client(integration)
    private_key_file_path = nil
    if !Rails.env.development? && !Rails.env.test?
      @private_key_file = Tempfile.new(['private_key_file', '.pem'])
      @private_key_file.binmode
      @private_key_file.write open(integration.private_key_file.url).read
      @private_key_file.rewind
      @private_key_file.close
      private_key_file_path = @private_key_file.path
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

  def fetch_text_from_html string
    Nokogiri::HTML(string).xpath("//*[p]").first.content rescue " "
  end

  def log(company, action, request, response, status)
    LoggingService::IntegrationLogging.new.create(company, 'JIRA', action, request, response, status)
  end
end
