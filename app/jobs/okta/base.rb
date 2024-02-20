class Okta::Base
  include Sidekiq::Worker
  sidekiq_options :queue => :manage_one_login_integration, :retry => false, :backtrace => true

  require 'net/http'
  require 'uri'
  require 'json'

  def sync_employees(uri, okta_integration, un_synced_users_emails)
    begin
      company = okta_integration.company
      request = Net::HTTP::Get.new(uri)
      request.content_type = "application/json"
      request["Accept"] = "application/json"
      request["Authorization"] = "SSWS #{okta_integration.api_key}"
      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      if [204, 200].exclude?(response.code.to_i)
        log(company, 'Sync', nil, {error: "Failed to fetch users from Okta integration: #{okta_integration.id}"}, response.code)
        return nil
      end

      body = JSON.parse(response.body)

      puts '+++++++++++++response-received++++++++++++'
      un_synced_users_emails.each do |user_emails|
        body.each do |okta_user|
          okta_email = okta_user.dig("profile").dig("login")
          email = user_emails[0] || user_emails[1]
          if email.downcase == okta_email.downcase
            company.users.find_by(email: user_emails[0], personal_email: user_emails[1]).update_column(:okta_id, okta_user["id"])
            okta_integration.update_column(:synced_at, DateTime.now)
          end
        end

      end
      links = parse_link_header(response['link'])
      return links[:next]
    rescue Exception => e
      log(company, 'Sync', nil, {error: e.message, integration: okta_integration.id}, 500)
      return nil
    end
  end

  def send_profile_to_okta(user, uri, okta_integration)
    begin
      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/json"
      request["Accept"] = "application/json"
      request["Authorization"] = "SSWS #{okta_integration.api_key}"
      user_profile = create_user_without_credentials(user)

      puts '-----------user_profile----------'

      user_profile = add_department_devision(user, user_profile)

      puts '-----------Ready----------'

      request.body = JSON.dump(user_profile)

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      body = JSON.parse(response.body)

      puts '+++++++++++++response-received++++++++++++'
      user.update_column(:okta_id, body["id"]) if body["id"].present?
      okta_integration.update_column(:synced_at, DateTime.now) if okta_integration
      return response, user_profile

    rescue Exception => e
      log(user.company, 'Create', nil, {error: e.message, integration: okta_integration.id}, 500)
      return nil, nil
    end
  end

  def add_department_devision user, user_profile
    if user.company.department == 'Department'
      user_profile[:profile][:department] = user.team&.name

    else
      department = CustomField.get_custom_field(user.company, 'Department')
      if department
        user_profile[:profile][:department] = CustomField.get_mcq_custom_field_value(department, user.id)
      end
    end

    if user.company.department == 'Division'
      user_profile[:profile][:division] = user.team&.name

    else
      division = CustomField.get_custom_field(user.company, 'Division')
      if division
        user_profile[:profile][:division] = CustomField.get_mcq_custom_field_value(division, user.id)
      end
    end
    user_profile
  end

  def create_user_without_credentials(user)
    login_email = user.email || user.personal_email
    if user.preferred_name.present?
      displayName = "#{user.preferred_name} #{user.last_name}"
    else
      displayName = "#{user.first_name} #{user.last_name}"
    end

    data = {
      profile: {
        firstName: user.first_name,
        lastName: user.last_name,
        email: login_email,
        secondEmail: user.personal_email,
        title: user.title,
        displayName: displayName,
        nickName: user.preferred_name,
        primaryPhone: handle_phone_field(user.get_custom_field_value_text('Home Phone Number')),
        login: login_email,
        mobilePhone: handle_phone_field(user.get_custom_field_value_text('Mobile Phone Number')),
        userType: user.employee_type_field_option&.option,
        managerId: user.manager_id,
        manager: user.manager&.full_name
      }.merge!(make_address(user))
    }

    if user.company.subdomain == 'upserve'
      upserve_custom_fields = {
        employeeNumber: user.get_custom_field_value_text('Paylocity EE Number'),
        RoleProfile: user.get_custom_field_value_text('Role Profile'),
        ManagerRole: user.get_custom_field_value_text('Manager Role')
      }
      data[:profile].merge!(upserve_custom_fields)
    end

    if user.company.subdomain == 'clari'
      data[:profile][:firstName] = get_user_name(user)
      data[:profile][:managerId] = user.manager&.email
    end

    if user.company.subdomain == 'truework'
      data[:profile][:manager] = user.manager&.email
      data[:profile][:office] = user.get_custom_field_value_text('Office Location')
    end

    if ['emersoncollective', 'moveworks'].include?(user.company.subdomain)
      data[:profile][:firstName] = get_user_name(user)
      data[:profile][:legalName] = user.first_name
      data[:profile][:location] = user.location_name
    end

    if user.company.subdomain == 'bloomerang'
      data[:profile][:managerId] = user.manager&.email
    end

    data
  end

  def make_address(user)
    user_address = {}
    custom_field = CustomField.get_custom_field(user.company, 'Home Address')

    address_custom_work.each do |key, value|
      next if value[:except].include?(user.company.subdomain) || (value.key?(:include) && value[:include].exclude?(user.company.subdomain))

      custom_field_value = CustomField.get_sub_custom_field_value(custom_field, "#{value[:name]}", user.id)
      if value[:name] == 'Country'
        custom_field_value = Country.find_by(name: custom_field_value)&.key
      end
      user_address.merge!("#{key}": custom_field_value)
    end

    user_address[:streetAddress] = user_address.delete(:line1).to_s + ' ' + user_address.delete(:line2).to_s if user_address.key?(:line1)
    user_address
  end

  def get_user_name(user)
    user.preferred_name || user.first_name
  end

  def log(company, action, request, response, status)
    @integration_logging ||= LoggingService::IntegrationLogging.new
    @integration_logging.create(company, 'Okta', action, request, response, status)
  end

  def parse_link_header(link_header)
    links = Hash.new
    parts = link_header.split(',')

    # Parse each part into a named link
    parts.each do |part, index|
      section = part.split(';')
      url = section[0][/<(.*)>/,1]
      name = section[1][/rel="(.*)"/,1].to_sym
      links[name] = url
    end
    return links
  end

  def handle_phone_field(value)
    value && value.start_with?("'+") ? value[1..-1] : value
  end

  def address_custom_work
    {
      line1: {name: 'Line 1', except: ['clari']},
      line2: {name: 'Line 2', except: ['clari']},
      state: {name: 'State', except: ['']},
      city: {name: 'City', except: ['clari']},
      zipCode: {name: 'Zip', except: ['clari']},
      countryCode: {name: 'Country', except: [''], include: ['clari']}
    }
  end

  def fetch_okta_host(sso_url) URI.parse(sso_url).host end
end
