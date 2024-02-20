module SlackService
  class BuildMessage
    attr_reader :user,:access_token,:integration,:slack_bot_access_token,:url

    def initialize(user,current_company, integration)
      @user = user
      @current_company = current_company
      @integration = integration
      @slack_bot_access_token = @integration.slack_bot_access_token
    end

    def prepare_attachments(message_content)
      slack_msg_collection= {}
      color = "#3F1DBC"
      if message_content[:type] == "assign_task"   # Assign Tasks
        task_receiver = @user
        workstream_name = nil
        message_content[:tasks].each do |task|
          next if !task.present?
          receiver  = nil
          if ['hire'].include?(task[:task_type])
            if task[:owner_id].present?
              receiver = find_user(task[:owner_id])
            else
              receiver = @user
            end
          elsif task[:owner_id].present?
            receiver = find_user(task[:owner_id])
          elsif task[:task_type] == 'manager'
            receiver = @user.manager
          elsif task[:task_type] == 'buddy'
            receiver = @user.buddy
          else
            next
          end

          next unless receiver.present?
          begin
            slack_id = receiver.get_slack_user_id(@integration)
          rescue Exception => e
            p "#------------------------Error-------------------------#"
            p "Find User on Slack WorkSpace - Assign Task"
            p e
            puts "Slack_ID: #{slack_id}"
            puts "Task_Owner: #{receiver}"
            p "#------------------------Error-------------------------#"
          end
          next if slack_id.nil? # user not present on slack
          attachment = {}
          attachment[:fallback] = "New Task"
          task_user_connections = TaskUserConnection.where(task_id: task[:id],user_id: @user.id).take rescue nil
          next if task_user_connections.nil? || (task_user_connections.workspace_id.present? && task_user_connections.owner_id == task_user_connections.user_id)
          attachment[:callback_id] = "sapling_task_complete"
          attachment[:color] = color
          workstream_name = Workstream.find_by(id: task[:workstream_id]).name rescue ''
          if task[:token_name]
            attachment[:title] =  fetch_text_from_html(ReplaceTokensService.new.replace_tokens(task[:token_name],@user,nil, nil, nil, true))
          else
            attachment[:title] =  fetch_text_from_html(ReplaceTokensService.new.replace_tokens(task[:name],@user,nil, nil, nil, true))
          end
          if task[:survey_id]
            attachment[:title_link] = "https://#{@current_company.app_domain}/#/survey/#{task_user_connections.id}"
          else
            attachment[:title_link] = "https://#{@current_company.app_domain}/#/tasks/#{receiver.id}?id=#{task_user_connections.id}"
          end
          if task[:description] && !slack_msg_collection.key?(slack_id)
            if task[:survey_id]
              attachment[:text] = "This survey task can only be completed in Sapling."
            else
              if task[:token_description]
                attachment[:text] = fetch_text_from_html(ReplaceTokensService.new.replace_tokens(task[:token_description],@user,nil, nil, nil, true))
              else
                attachment[:text] = fetch_text_from_html(ReplaceTokensService.new.replace_tokens(task[:description],@user,nil, nil, nil, true))
              end
            end
          elsif slack_msg_collection.key?(slack_id) && slack_msg_collection[slack_id].length <= 1
            slack_msg_collection[slack_id].each do |attach|
              attach[:text] = ""
            end
          end
          attachment[:fields] = [
              {
                  "title": "Workflow",
                  "value": "#{workstream_name}",
                  "short": true
              },
              {
                  "title": "Due Date",
                  "value": "#{task_user_connections.due_date}",
                  "short": true
              }
          ]
          attachment[:footer] = "#{receiver.title} - #{receiver.try(:team).try(:name)} In #{receiver.try(:location).try(:name)}"
          key = SecureRandom.hex
          crypt = ActiveSupport::MessageEncryptor.new(key)
          data = "#{@current_company.id}_#{task_user_connections.id}_#{receiver.id}"
          encrypted_data = crypt.encrypt_and_sign(data)
          if task[:survey_id].nil?
            attachment[:actions] = [
                {
                    "name": "task_complete",
                    "text": "Mark as Complete",
                    "type": "button",
                    "value": "#{key}_#{encrypted_data}",
                    "style": "primary",
                }
            ]
          end
          attachment[:task_receiver] = task_receiver.id
          attachment[:task_receiver_name] = task_receiver.display_name
          if !slack_msg_collection.key?(slack_id) && slack_id != nil
            slack_msg_collection[slack_id] = Array.new
            slack_msg_collection[slack_id] = [attachment]
          elsif slack_id != nil
            slack_msg_collection[slack_id].push(attachment)
          end
        end
      elsif  message_content[:type] == "admin_welcome_message"    # Admin Welcome Message

        admin_name = @user.preferred_full_name

        @user.slack_notification = true
        @user.save!
        attachment = {}
        attachment[:callback_id] = "push_notification_to_public_channel"
        attachment[:color] = color
        attachment[:title] = "Sapling Slack Integration"
        attachment[:text] = "Hey #{admin_name}! :wave::skin-tone-5: #{I18n.t('admin.settings.integrations.slack_integration.admin_slack_welcome_message')} \n\n*Just one more thing* \n #{I18n.t('admin.settings.integrations.slack_integration.admin_check_send_notification')} "
        attachment[:fallback]  = attachment[:text]
        attachment[:fields] = []
        attachment[:actions] = [
            {
                "name": "select_channel_#{@current_company.id}",
                "text": "Select a channel",
                "type": "select",
                "options": get_channels_list
            }
        ]
        begin
          slack_id = @user.get_slack_user_id(@integration)
        rescue Exception => e
          p "#------------------------Error-------------------------#"
          p "Find User on Slack WorkSpace - Admin Welcome Message"
          p e
          puts "Slack_ID: #{slack_id}"
          puts "Admin User: #{@user}"
          p "#------------------------Error-------------------------#"
        end
        if slack_id != nil
          @user.update_column(:slack_id, slack_id)
          slack_msg_collection[slack_id] = Array.new
          slack_msg_collection[slack_id] = [attachment]
        end

      elsif message_content[:type] == "push_notification_to_public_channel" ## Request Enable Notification
        attachment = {}
        attachment[:fallback] = "Exciting news from Sapling"
        attachment[:callback_id] = "push_notification_to_public_channel"
        attachment[:color] = color
        attachment[:title] = "Sapling for Slack is here! :raised_hands::skin-tone-5:"
        attachment[:text] = "#{I18n.t('admin.settings.integrations.slack_integration.welcome_message_to_everyone')} <https://#{@current_company.app_domain}/#/account_settings|your settings.>"
        slack_id = @user

        if slack_id != nil
          slack_msg_collection[slack_id] = Array.new
          slack_msg_collection[slack_id] = [attachment]
        end
      end
      slack_msg_collection
    end

    private

    def get_channels_list
      client = Slack::Web::Client.new
      client.token = @integration.slack_bot_access_token
      begin
        response = client.conversations_list({limit: 200, exclude_archived: true})
        channels = []
        if response["ok"]
          response["channels"].each do |channel|
            if channel["is_channel"]
              channels.push({text: channel["name"],value: channel["id"]})
            end
          end
          until !response["response_metadata"]["next_cursor"].present?
            response = client.conversations_list({limit: 200, exclude_archived: true, cursor: response["response_metadata"]["next_cursor"]})
            response["channels"].each do |channel|
              if channel["is_channel"]
                channels.push({text: channel["name"],value: channel["id"]})
              end
            end
          end
        end
        log('Get Channels List', 'conversations_list', response, 200)
        channels
      rescue Exception => e
        log('Get Channels List', e.message, response, 500)
      end
    end

    def fetch_text_from_html(string)
      Nokogiri::HTML(string).text
    end

    def find_user(id)
      User.find_by(id: id)
    end

    def log(action, request, response, status)
      begin
        LoggingService::IntegrationLogging.new.create(@current_company, 'Slack Notification', action, request, response, status)
      rescue Exception => e
        @current_company.loggings.create(integration_name: 'Slack Notification', state: status, action: action + " (Error: #{e.message})", api_request: request, result: response)
      end
    end
  end
end
