module AtsIntegrations
  class SmartRecruiters

    require 'uri'
    require 'net/http'

    def initialize(company, smart_recruiters_api = nil, code = nil)
      @company = company
      @smart_recruiters_api = smart_recruiters_api
      @code = code
    end

    def retrieve_authorization_token
      message = "not_retrieved"
      webhook_executed = 'failed'
      error = nil
      begin
        url = URI('https://www.smartrecruiters.com/identity/oauth/token')

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        request = Net::HTTP::Post.new(url)
        request["content-type"] = 'application/x-www-form-urlencoded'
        request["cache-control"] = 'no-cache'
        request["postman-token"] = 'ca2802f0-d8ce-6726-199a-f3ed411d9a92'
        request.body = "grant_type=authorization_code&code=#{@code}&client_id=#{@smart_recruiters_api.client_id}&client_secret=#{@smart_recruiters_api.client_secret}"
        response = http.request(request)
        data = JSON.parse(response.read_body)

        message = "retrieved" if data['access_token'].present?

        @smart_recruiters_api.expires_in(Time.now + data['expires_in'].to_i)
        @smart_recruiters_api.refresh_token(data['refresh_token'])
        @smart_recruiters_api.access_token(data['access_token'])
        create_webhook_logging(@company, 'Retrieve Access Token', { data: response.read_body.to_json, request: "https://www.smartrecruiters.com/identity/oauth/token?client_id=#{@smart_recruiters_api.client_id}&client_secret=#{@smart_recruiters_api.client_secret}&code=#{@code}" }, 'succeed', 'Lib::SmartRecruiters/retrieve_authorization_token') rescue nil
        @smart_recruiters_api.reload
        webhook_executed = 'succeed'

        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(@company)
      rescue Exception => e
        error = e.message
        create_webhook_logging(@company, 'Retrieve Access Token', { request: "https://www.smartrecruiters.com/identity/oauth/token?client_id=#{@smart_recruiters_api.client_id}&client_secret=#{@smart_recruiters_api.client_secret}&code=#{@code}" }, webhook_executed, 'Lib::SmartRecruiters/retrieve_authorization_token', e.message) rescue nil
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(@company)
      ensure
        create_webhook_logging(@company, 'Created by API', data.to_json, webhook_executed, 'Lib::SmartRecruiters/retrieve_authorization_token', error)
      end

      return message
    end

    def refresh_authorization_token
      url = URI('https://www.smartrecruiters.com/identity/oauth/token')

      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      request = Net::HTTP::Post.new(url)
      request["content-type"] = 'application/x-www-form-urlencoded'
      request["cache-control"] = 'no-cache'
      request["postman-token"] = 'ca2802f0-d8ce-6726-199a-f3ed411d9a92'
      request.body = "grant_type=refresh_token&refresh_token=#{@smart_recruiters_api.refresh_token}&client_id=#{@smart_recruiters_api.client_id}&client_secret=#{@smart_recruiters_api.client_secret}"
      response = http.request(request)
      data = JSON.parse(response.read_body)

      @smart_recruiters_api.expires_in(Time.now + data['expires_in'].to_i)
      @smart_recruiters_api.refresh_token(data['refresh_token'])
      @smart_recruiters_api.access_token(data['access_token'])
      create_webhook_logging(@company, 'Refresh Access Token', { data: response.read_body.to_json, request: "grant_type=refresh_token&refresh_token=#{@smart_recruiters_api.refresh_token}&client_id=#{@smart_recruiters_api.client_id}&client_secret=#{@smart_recruiters_api.client_secret}" }, 'succeed', 'Lib::SmartRecruiters/refresh_authorization_token') rescue nil
      @smart_recruiters_api.reload
    end

    def import
      response = { response: "not_imported" }
      begin
        refresh_authorization_token() if Time.now.utc > @smart_recruiters_api.expires_in
        response = HTTParty.get("https://api.smartrecruiters.com/candidates?limit=100&offset=0&status=HIRED",
          headers: { accept: "application/json", authorization: "Bearer #{@smart_recruiters_api.access_token}" }
        )

        candidates = JSON.parse(response.body)
        candidates['content'].try(:each) do |candidate|
          create(candidate)
        end
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(@company)
        @smart_recruiters_api.update_column(:synced_at, DateTime.now) if @smart_recruiters_api
        return { response: "imported" }
      rescue Exception => e
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_webhook_statistics(@company)
        puts "---------------SMART RECRUITERS---------------"
        puts e.inspect
        puts "----------------------------------------------\n"*3
      end
      return response
    end

    private
    def create(data)
      if user_does_not_exist?(data['email'])
        pending_hire_data = {}
        pending_hire_data[:personal_email] = data['email'] rescue nil
        pending_hire_data[:first_name] = data['firstName'] rescue nil
        pending_hire_data[:last_name] = data['lastName'] rescue nil
        pending_hire_data[:title] = data['primaryAssignment']['job']['title'] rescue nil
        pending_hire_data[:start_date] = data['createdOn'] rescue nil
        pending_hire_data[:city] = data['location']['city'] rescue nil
        pending_hire_data[:address_state] = data['location']['regionCode'] rescue nil
        job = job_details(data['primaryAssignment']['job']['actions']['details']['url']) rescue {}
        pending_hire_data[:employee_type] = job['typeOfEmployment']['label'].parameterize.underscore rescue nil
        pending_hire_data[:department] = job['function']['label'] rescue nil
        pending_hire_data[:location] = job['location']['city'] rescue nil
        pending_hire_data[:company_id] = @company.id
        PendingHire.create_by_smart_recruiters(pending_hire_data, @company)
      end
    end

    def create_webhook_logging(company, action, data, webhook_executed, location, error=nil)
      @webhook_logging ||= LoggingService::WebhookLogging.new
      @webhook_logging.create(company, 'Smart Recruiters', action, data, webhook_executed, location, error)
    end

    def job_details(url = nil)
      refresh_authorization_token() if Time.now.utc > @smart_recruiters_api.expires_in
      response = HTTParty.get(url,
        headers: { accept: "application/json", authorization: "Bearer #{@smart_recruiters_api.access_token}" }
      )
      JSON.parse(response.body) rescue {}
    end

    def user_does_not_exist?(email = nil)
      return true if !email.present?
      @company.users.where('email ILIKE ? OR personal_email ILIKE ?', email, email).count == 0 && @company.pending_hires.where('personal_email ILIKE ?', email).count == 0
    end
  end
end
