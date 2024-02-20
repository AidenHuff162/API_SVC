module Integrations
  module SlackNotification
    class Push

      require 'slack-ruby-client'

      def self.push_notification(slack_attachments, current_company, integration, public_channel = false, message_type = "", task_due_date_change = false)
        return if current_company.inactive?
        
        client = Slack::Web::Client.new
        client.token  = integration.slack_bot_access_token
        slack_attachments.each do |slack_id,attachments|
          message = {}
          if message_type == "Task_Assign"
            if attachments.length > 1
              message[:text] = "You've been assigned #{attachments.length} tasks to complete for <https://#{current_company.domain}/#/profile/#{attachments.first[:task_receiver]}|#{attachments.first[:task_receiver_name]}> in Sapling"
            else
              if task_due_date_change
                message[:text] = "You have a new due date for the following task in Sapling:"
              else
                message[:text] = "You've been assigned a task to complete for <https://#{current_company.domain}/#/profile/#{attachments.first[:task_receiver]}|#{attachments.first[:task_receiver_name]}> in Sapling"
              end
            end
          elsif message_type == 'tasks'
            message[:text] = '*Incomplete and overdue tasks:*' 
          elsif message_type == 'PTO_Approval_Status'
            
            pto_request = PtoRequest.find(attachments.first[:id])
            next unless pto_request.present?
            
            pto_policy = pto_request.pto_policy
            next unless pto_policy.present?

            message[:blocks] = [{
              :type => "section",
              :text => {
                :type => "mrkdwn",
                :text => "*Time off #{attachments.first[:status]}!*\n#{pto_request.begin_date.to_date.strftime('%b %d, %Y')} - #{pto_request.get_end_date.to_date.strftime('%b %d, %Y')}\n*Type:* #{pto_policy.policy_type}\n*Length:* #{pto_request.get_request_length()}\n<https://#{current_company.domain}/#/time_off/#{attachments.first[:user_id]}|View in Sapling>"
              }
            }]
          end

          message[:channel] = slack_id
          message[:attachments] = attachments unless message_type == 'PTO_Approval_Status'
          if public_channel == false
            message[:as_user] = true
            message[:username] = "Sapling"
          end
          begin
            client.chat_postMessage(message)
            integration.update_column(:last_sync, DateTime.now)
          rescue Exception => e
            p e.message
          end
        end
      end
    end
  end
end
