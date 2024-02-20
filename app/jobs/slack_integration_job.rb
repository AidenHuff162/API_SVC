class SlackIntegrationJob
  include Sidekiq::Worker
  sidekiq_options :queue => :slack_integration, :retry => false, :backtrace => true

  def perform(type = nil , main_payload = nil, task_due_date_change = false)
    if type.present?
      main_payload = (type == 'Task_Assign' || type == 'PTO_Approval_Status') ? main_payload.deep_symbolize_keys : main_payload.symbolize_keys
      if ['team', 'time', 'out', 'tasks', 'request'].include? type
        @payload = main_payload[:payload]
        initialize_default_data(type, @payload['team_id'], @payload['user_id'])
      end
      if type == "Slack_Auth" && main_payload
        payload = main_payload[:payload]
        ids = main_payload[:state]
        company = Company.find_by(id: ids["company_id"])
        user = company.users.find_by(id: ids["user_id"]) if company.present?
        return unless (company.present? && user.present?)
        client = SlackService::SlackWorkspaceAuthenticate.new(payload,company)
        client.authenticate?(user)
      elsif type == "Slack_Respond"
        payload = main_payload[:payload]
        begin
          payload = JSON.parse(payload["payload"]) if payload["payload"]
          block_id = payload['message']['blocks'][0]['block_id'] rescue nil
          action_id = payload['actions'][0]['action_id'] rescue nil
          if ['out_of_office', 'time_off_request_approve_deny'].include?(block_id)
            initialize_default_data(block_id, payload['team']['id'], payload['user']['id'])
            respond_service = SlackService::RespondToInteractiveMessage.new(payload, @client, @user, block_id)
            respond_service.respond
          elsif action_id == 'partial_day_included'
            initialize_default_data('partial day included clicked', payload['team']['id'], payload['user']['id'])
            @user.update_partial_day_view(@integration, payload)
          elsif payload['type'] == 'view_submission' && payload["view"] && payload["view"]["callback_id"] && payload["view"]["callback_id"] == 'submit_pto_request'
            @payload = payload
            @payload['user_id'] = @payload['user']['id']
            initialize_default_data('Pto request submit from slack', payload['team']['id'], payload['user']['id'])
            message = @user.save_pto_request(payload)
            post_message_on_slack(message)
          elsif action_id == 'timeoff_show_more'
            value = payload['actions'][0]['value'] rescue nil
            @payload = payload
            @payload['user_id'] = @payload['user']['id']
            initialize_default_data('Pto request show more from slack', payload['team']['id'], payload['user']['id'])
            respond_service = SlackService::RespondToInteractiveMessage.new(payload, @client, @user, 'available_time_off_policies')
            respond_service.respond
            if @user && value.present?
              details = @user.get_policies_for_slack(value.to_i)
              post_message_on_slack(details)
            end
          else
            client = SlackService::PushSlackInteractiveMessage.new(payload)
            client.process_response?
          end
        rescue Exception => e
          puts "--------------------- Slack Slack_Respond --------------------"
          p e
        end

      elsif type == 'post_help_message'
        payload = main_payload[:payload]
        user = User.find_by(slack_id: payload['event']['user'])
        unless user
          initialize_default_data(type, payload['team_id'], payload['event']['user'])
          message = {blocks: [{"type": "section","text": 
            {"type": "mrkdwn","text": "Check out the knowledge base article <https://kallidus.zendesk.com/hc/en-us/articles/360018812798-Sapling-Slack-Integration-Guide|here> for more information about how to use the Sapling bot, or contact your People Operations department."}
          }]}
          if @user.present?
            message[:channel] = payload['event']['user']
            message[:as_user] = true
            message[:username] = "Sapling"
            @client.chat_postMessage(message)
          end
        end
      elsif type == "Slack_Help"
        url = main_payload[:payload]["response_url"]
        payload = {}
        payload[:text] = "Check out the knowledge base article <https://kallidus.zendesk.com/hc/en-us/articles/360018812798-Sapling-Slack-Integration-Guide|here> for more information about how to use the Sapling bot, or contact your People Operations department."
        payload[:response_type]= "in_channel"
        begin
          response=RestClient.post(url, payload.to_json,{:content_type => 'application/json'})
        rescue Exception => e
          puts "--------------------- Slack Notification --------------------"
          p e
        end

      elsif type == 'team'
        if @user
          details = @user.get_team_details_on_slack
          post_message_on_slack(details)
        end
      elsif type == 'out'
        if @user
          details = @user.get_team_out_of_office_details
          post_message_on_slack(details)
        end
      elsif type == 'time' #Get user's polices
        if @user
          details = @user.get_policies_for_slack
          post_message_on_slack(details)
        end
      elsif type == 'tasks'
        if @user
          details = @user.get_tasks_for_slack(@integration, type)
          post_message_on_slack(details) 
        end
      elsif type == 'request'
        if @user
          details = @user.send_timeoff_form(@integration, main_payload) 
          post_message_on_slack(details) if details.present?
        end
      elsif type == "Task_Assign"
        current_company = Company.find_by(id: main_payload[:current_company_id])
        message_content = main_payload[:message_content]
        if current_company.present?
          user = current_company.users.find_by(id: main_payload[:user_id].to_i)
          owner = current_company.users.find_by(id: message_content[:tasks][0][:owner_id].to_i)
          integration = current_company.integrations.find_by(api_name: 'slack_notification')
        end 
        return unless check_if_task_in_progress?(message_content[:tasks][0][:id], user)

        return unless (integration.present? && user.present? && (message_content[:tasks][0][:owner_id].present? ? owner.slack_notification.present? : user.slack_notification.present?))
        slack = SlackService::BuildMessage.new(user,current_company, integration)
        attachments = slack.prepare_attachments(message_content)
        unless attachments.nil?
          begin
            Integrations::SlackNotification::Push.push_notification(attachments,current_company, integration, false, type, task_due_date_change)
          rescue Exception => e
            puts "--------------------- Slack Notification --------------------"
            p e
          end
        end
      elsif type == "Disable_Users_Slack_Notification"
        current_company = Company.find_by(id: main_payload[:current_company_id])
        current_company.users.update_all({slack_notification: false, email_notification: true}) if current_company.present?
      elsif type == "PTO_Approval_Status"
        current_company = Company.find_by(id: main_payload[:current_company_id])
        user = current_company.users.find_by(id: main_payload[:user_id].to_i) if current_company.present?
        message_content = main_payload[:message_content]
        integration = current_company.integrations.find_by(api_name: 'slack_notification') if current_company.present?

        return unless (integration.present? && user.present?)
        begin
          attachments = {}
          attachments[user.slack_id] = main_payload[:message_content][:pto_request]
          Integrations::SlackNotification::Push.push_notification(attachments, current_company, integration, false, type)
        rescue Exception => e
          puts "--------------------- Slack Notification --------------------"
          p e
        end    
      end
    end
  end

  private
  def log(company, action, request, response, status)
    LoggingService::IntegrationLogging.new.create(company, 'Slack Notification', action, request, response, status)
  end

  def initialize_default_data(type, slack_team_id, slack_user_id)
    begin
      @integration = Integration.find_by(slack_team_id: slack_team_id)
      @company = @integration.try(:company)
      return unless @integration.present?
      @client = Slack::Web::Client.new
      @client.token = @integration.slack_bot_access_token
      @user = @company.users.find_by(slack_id: slack_user_id)
      unless @user
        user_info = @client.users_info(user: slack_user_id)
        if user_info.present? && user_info['ok']
          email = user_info["user"]["profile"]["email"] rescue nil
          @user = @company.users.where('email = :email OR personal_email = :email',email: email).take if email.present?
          @user.update_column(:slack_id, slack_user_id) if @user.present?
        else
          log(@company, "slack slash command #{type}", nil, user_info.inspect, 200)
        end
      end
    rescue Exception => e
      log(@company, 'sapling team command', nil, e.message, 500)
    end
  end

  def post_message_on_slack(message)
    begin
      message[:channel] = @payload['user_id']
      message[:as_user] = true
      message[:username] = "Sapling"
      @client.chat_postMessage(message)
    rescue Exception => e
      log(@company, 'Slack post message error', nil, e.message, 500)
    end
  end

  def check_if_task_in_progress? task_id, user
    user.task_user_connections.where('(task_id = (?) AND state = (?))', task_id, 'in_progress').load.any? rescue false
  end
end
