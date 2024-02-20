module SlackService
  class SlackWorkspaceAuthenticate
    attr_reader :verification_code,:url,:integration,:current_company
    def initialize(verification_code,current_company)
      @verification_code = verification_code["code"]
      @url = I18n.t('admin.settings.integrations.slack_integration.api_url')
      @current_company = current_company
      @integration = @current_company.integrations.find_by(api_name: "slack_notification") rescue nil
    end


    def authenticate?(user)
      @url += "oauth.v2.access?client_id=#{ENV['SLACK_CLIENT_ID']}&client_secret=#{ENV['SLACK_CLIENT_SECRET']}&code=#{@verification_code}"
      begin
        response = JSON.parse(RestClient::Request.execute(method: :get, url: @url))
        log('Authenticate', @url, response.inspect, 200)
      rescue
        log('Authenticate', @url, response.inspect, 500)
      end
      if @integration.nil? && response && response['access_token']    # if Slack Integration is not exist and access Token is there Create New Integration
        result = {}
        result[:slack_bot_access_token] = response['access_token']
        result[:api_name] = "slack_notification"
        result[:is_enabled] = true
        result[:slack_team_id] = response["team"]["id"]
        @integration = @current_company.integrations.create!(result)
        slack = SlackService::BuildMessage.new(user, @current_company, @integration)
        attachment = slack.prepare_attachments({type: "admin_welcome_message"})
        unless attachment.nil?
          begin
            Integrations::SlackNotification::Push.push_notification(attachment,@current_company, @integration)
          rescue Exception => e
            puts "#------------------------Error-------------------------#"
            puts "Push Notification To Admin User - Push Notification"
            puts e
            puts "Slack_ID: #{attachment}"
            puts "#------------------------Error-------------------------#"
          end
        end
      elsif response['access_token']       # if Integration exist and access_token is also exist , Update the Exist token
        @integration.slack_bot_access_token = response['access_token']
        @integration.save! ? true : false
      end
      response["access_token"].nil? ? false : true
    end
    
    def log (action, request, response, status)
      LoggingService::IntegrationLogging.new.create(@current_company, 'Slack Notification', action, request, response, status)
    end
  end
end
