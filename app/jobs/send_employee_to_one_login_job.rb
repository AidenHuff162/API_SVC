class SendEmployeeToOneLoginJob < ApplicationJob
  queue_as :manage_one_login_integration

  def perform(user_id)
    require 'net/http'
    require 'uri'
    require 'json'
    puts '-------------inside-one-login-job----------------'
    user = User.find_by_id(user_id)
    return if !user.present? || user.super_user

    one_login_integration = user.company.integration_instances.find_by(api_identifier: 'one_login', state: :active)

    return unless one_login_integration.present? && one_login_integration.enable_create_profile && one_login_integration.client_id && one_login_integration.client_secret

    if !user.one_login_id.present? && one_login_integration.present? && one_login_integration.enable_create_profile

      token = JSON.parse(access_token(one_login_integration))

      if token["status"]
        puts "----------error_in_access_token-------------"
        log(user.company, 'Create', 'request connection', {result: token}, 500)
        return
      end

      uri = URI.parse("https://api.#{one_login_integration.region.downcase}.onelogin.com/api/1/users")
      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/json"
      request["Authorization"] = "bearer:#{token["access_token"]}"

      user_profile = create_profile(user)

      if user.company.department == 'Department'
        user_profile[:department] = user.team&.name

      else
        department = CustomField.get_custom_field(user.company, 'Department')
        if department
          user_profile[:department] = CustomField.get_mcq_custom_field_value(department, user.id)
        end
      end

      request.body = JSON.dump(user_profile)

      puts '----------profile-ready----------------'

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      response_body = JSON.parse(response.body)

      if response_body["status"]["error"]
        puts '---------------error-while-creating-user----------------'
        log(user.company, 'Create', 'request connection', {result: response_body}, 500)
      else
        puts '-----------User-created-successfully-------------'
        log(user.company, 'Create', 'request connection', {result: response_body}, 200)
        one_login_id = response_body["data"][0]["id"]
        user.update_column(:one_login_id, one_login_id)
        
        manage_custom_attributes(user.reload, token, one_login_integration)
      end
    end
  end

  def access_token(integration)
    require 'httparty'

    response = HTTParty.post("https://api.#{integration.region.downcase}.onelogin.com/auth/oauth2/v2/token",
      basic_auth: {
        username: integration.client_id,
        password: integration.client_secret
      },
      body: { grant_type: 'client_credentials' }.to_json,
      headers: {
        'content-type' => 'application/json'
      }
    )
    puts '----------------token-response-received-----------------'
    response.body
  end

  def create_profile(user)
    data = {
      firstname:  user.first_name,
      lastname:  user.last_name,
      email:  user.email,
      username:  user.first_name.to_s + "." + user.last_name.to_s,
      company: user.company.name,
      distinguished_name: user.preferred_name,
      member_of: user.team&.name,
      phone: CustomField.get_custom_field_value(CustomField.get_custom_field(user.company, 'Mobile Phone Number'), user.id),
      title: user.title,
      manager_user_id: user.manager&.one_login_id
    }
  end

  def manage_custom_attributes(user, token, one_login_integration)
    custom_attributes = build_custom_attributes(user)
    update_custom_attributes(user, token, one_login_integration, custom_attributes)
  end

  def format_date(value)
    return unless value.present?
    value.to_date.strftime('%Y-%m-%d')  
  end

  def build_custom_attributes(user)
    custom_attributes = {
      custom_attributes: {
        location: user.location&.name
      }
    }

    if user.company.subdomain.eql?('compass')    
      custom_attributes[:custom_attributes][:market]    = user.get_custom_field_value_text('Market')
      custom_attributes[:custom_attributes][:submarket] = user.get_custom_field_value_text('Sub-Market')
      custom_attributes[:custom_attributes][:office]    = user.get_custom_field_value_text('Office Location')
    end
    custom_attributes
  end

  def update_custom_attributes(user, token, one_login_integration, data)
    uri = URI.parse("https://api.#{one_login_integration.region.downcase}.onelogin.com/api/1/users/#{user.one_login_id}/set_custom_attributes")
    request = Net::HTTP::Put.new(uri)
    request.content_type = "application/json"
    request["Authorization"] = "bearer:#{token["access_token"]}"
    request.body = JSON.dump(data)

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    response_body = JSON.parse(response.body)

    if response_body["status"]["error"]
      puts '---------------error-while-creating-user----------------'
      log(user.company, 'Update Custom Attributes', data, {result: response_body}, 500)
    else
      puts '-----------User-created-successfully-------------'
      log(user.company, 'Update Custom Attributes', data, {result: response_body}, 200)
    end
  end

  def log(company, action, request, response, status)
    LoggingService::IntegrationLogging.new.create(company, 'OneLogin', action, request, response, status)
  end
end
