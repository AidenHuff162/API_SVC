module SlackService
  class PushSlackInteractiveMessage

    attr_reader :payload,:url,:action_type,:response_url,:destination_channel,:actions,:message_ts,:current_company,:original_message,:url,:client,:integration,:access_token

    def initialize(payload = nil)
      @payload = payload
      return if @payload.nil?
      @actions = find_payload_actions
      @current_company = find_current_company
      @url = initialize_url
      @action_type = @payload["callback_id"]
      @client = Slack::Web::Client.new
      @integration = @current_company.integrations.find_by(api_name: 'slack_notification') if @current_company.present?
      return if @integration.nil?
      @access_token = @integration.access_token
      @client.token = @integration.slack_bot_access_token
      @response_url = @payload["response_url"]
      @destination_channel = find_destination_channel
      @original_message = @payload["original_message"]
      @message_ts = find_message_time_stamp

    end

    # Type = Type of the Message [Task,Time Off Request,etc]

    def process_response?
      if @action_type == "sapling_task_complete"                        ## Send Respond To Slack User When Task Completed

        encrypted_data = @actions["value"].split("_")
        crypt = ActiveSupport::MessageEncryptor.new(encrypted_data.first)
        ids = crypt.decrypt_and_verify(encrypted_data.last).split("_") #[Current_Company_id, Task_ID, Task_Receiver_ID]
        task_user_connection_id = ids[1]
        task_receiver = ids[2]
        initialize_url
        task_user_connection = TaskUserConnection.find_by(id: task_user_connection_id.to_i)
        task_receiver = @current_company.users.find_by(id: task_receiver)
        return unless (task_user_connection.present? && task_receiver.present?)
        begin
          task_user_connection.agent_id = task_receiver.id
          task_user_connection.completed_by_method = TaskUserConnection.completed_by_methods[:slack]
          task_user_connection.mark_task_completed
          history_description = I18n.t('history_notifications.task.completed', name: task_user_connection.task[:name], assignee_name: task_receiver.try(:full_name))
          History.create_history({
                                     company: @current_company,
                                     user_id: task_receiver.id,
                                     description: history_description,
                                     attached_users: [task_user_connection.owner.try(:id)],
                                 })
          log("#{@current_company&.name} - Sapling Task Completed From Slack", @url, {tuc: task_user_connection.inspect, user: task_receiver.inspect}, 200)
          result=@client.chat_update(reconstruct_attachment(true,{task_receiver: task_receiver}))
          @integration.update_column(:last_sync, DateTime.now)
          log('Sapling Task Complete, Process_response', @url, result.inspect, 200)
        rescue Exception => e
          result=@client.chat_update(reconstruct_attachment(false))
          log('Sapling Task Complete, Process_response', @url, result.inspect, 500)
        end
      elsif @action_type == "push_notification_to_public_channel"      ## Push Notification to public channel
        ## Sending Message
        channelId =@actions["selected_options"].first["value"]
        message = BuildMessage.new(channelId,@current_company,@integration)
        attachment = message.prepare_attachments({type: "push_notification_to_public_channel"})
        Integrations::SlackNotification::Push.push_notification(attachment,@current_company, @integration, true)
        begin
          user=@payload["user"]
          channel_name = find_channel(channelId)
          @client.chat_postMessage(channel: user["id"], text: "Great - we've sent the message to #{channel_name} channel :+1::skin-tone-5: ", as_user: true)
          @integration.update_column(:last_sync, DateTime.now)
        rescue Exception => e
          log('Sapling Task Complete, Process_response', @url, e.message, 500)
        end
      end
    end

    private

    def find_destination_channel
      return nil if @payload["channel"].nil?
      @payload["channel"]["id"]
    end

    def find_payload_actions
      return nil if @payload["actions"].nil?
      @payload["actions"].first
    end

    def find_message_time_stamp
      return nil if @original_message["ts"].nil?
      @original_message["ts"]
    end

    def reconstruct_attachment(status,options=nil)
      attachment_id = @payload["attachment_id"]
      title = nil
      if status
        if @action_type == "sapling_task_complete"
          title = "\n Task marked as completed :+1::skin-tone-5:"
        # elsif @action_type == "push_notification_to_public_channel"
        #   title = "\n Great - we've sent the message to #{options[:channel_name]}! :+1::skin-tone-5:\n"
        end
      else
        title = "\n Something went wrong :interrobang:"
      end

      new_field =   {
          "title": title,
          "value": "" ,
          "short": true
      }

      message = {}
      if @action_type == "sapling_task_complete" || @action_type == "push_notification_to_public_channel"
        message[:text] = @original_message["text"]
      else
        message[:text] = ""
      end
      message[:channel] = @destination_channel
      message[:username] = "Sapling"
      message[:ts] = @message_ts
      attachment_collection = []
      @original_message["attachments"].each do |attachment|
        if attachment["id"] == attachment_id.to_i
          attachment.delete("actions") if @action_type != "push_notification_to_public_channel"
          if attachment["fields"].nil?
            attachment["fields"] = []
          end
          attachment["fields"].push(new_field)
        end
        attachment_collection.push(attachment)
      end
      message[:attachments] = attachment_collection
      message
    end

    def find_current_company
      if @actions["type"] == "select"
        original_message = @payload["original_message"]
        current_company_id = original_message["attachments"].first["actions"].first["name"].split("_").last
      elsif @actions["type"] == "button"
        encrypted_data = @actions["value"].split("_")
        crypt = ActiveSupport::MessageEncryptor.new(encrypted_data.first)
        current_company_id = crypt.decrypt_and_verify(encrypted_data.last).split("_").first
      end
      Company.find_by(id: current_company_id.to_i) if current_company_id.present?
    end

    def find_channel(channelid)
      begin
        response = @client.channels_info(channel: channelid)
        return response["channel"]['name'] if (response["ok"] && response["channels"].present? && response["channel"]['name'])
      rescue
        log('Get Channels List', @url, response, 500)
      end
    end

    def initialize_url
      @url = I18n.t('admin.settings.integrations.slack_integration.api_url')
    end

    def log(action, request, response, status)
      LoggingService::IntegrationLogging.new.create(@current_company, 'Slack Notification', action, request, response, status)
    end
  end
end
