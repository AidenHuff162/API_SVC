module TimeOff
  class SendRequestOnSlack
    include Sidekiq::Worker
    sidekiq_options queue: :default

    def perform(time_off_request, approval_user_id)
      @pto_request = PtoRequest.find_by(id: time_off_request)
      @user = User.find_by(id: approval_user_id)
      return unless (@user.present? && @pto_request.present? && @user.slack_notification)
      @company = @user.company
      integration = @company.integrations.find_by(api_name: 'slack_notification') if @company.present?
      return unless integration.present?
      @client = Slack::Web::Client.new
      @client.token = integration.slack_bot_access_token
      begin
        user_on_slack = @client.users_lookupByEmail({email: @user.email || @user.personal_email})
        if user_on_slack &&  user_on_slack['ok']
          @slack_user_id = user_on_slack['user']['id']
          post_time_off_request_on_slack
        end
      rescue Exception => e
        log(@company, 'Post time or request', nil, e.message, 500)
      end
    end

    private

    def post_time_off_request_on_slack
      message = @user.prepare_time_off_request_message(@pto_request)
      message[:channel] = @slack_user_id
      message[:as_user] = true
      message[:username] = "Sapling"
      @client.chat_postMessage(message)
    end

    def log(company, action, request, response, status)
      LoggingService::IntegrationLogging.new.create(company, 'Slack Notification', action, request, response, status)
    end
  end
end
