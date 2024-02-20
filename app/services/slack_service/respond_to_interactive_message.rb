module SlackService
  class RespondToInteractiveMessage
    def initialize(payload = nil, client, user, type)
      @payload = payload
      @client = client
      @user = user
      @type = type
      @message = {}
    end

    def respond
      if @type == 'out_of_office'
        @message = @user.respond_out_of_office(@payload)
      elsif @type == 'time_off_request_approve_deny'
        @message = @user.respond_approve_time_off_request(@payload)
      elsif @type == 'available_time_off_policies'
        @message = @user.get_policies_for_slack(nil, @payload)
      end
      push_message_on_slack
    end

    def push_message_on_slack
      @message[:ts] = @payload["message"]["ts"]
      @message[:channel] = @payload["channel"]["id"]
      @client.chat_update(@message)
    end
  end
end
