require 'net/http'
require 'uri'
require 'json'

class SsoIntegrationsService::OneLogin::User < SsoIntegrationsService::OneLogin::Initializer

  def initialize(company)
    super(company)
  end

  def create(data)
    return unless can_create_profile?
    execute(data)
  end

  def update(data, one_login_id = nil)
    unless one_login_id.present? && can_update_profile?
      return "update disabled"
    end 
    return unless data.present?
    execute(data, one_login_id)
  end

  def fetch(page = nil)
    execute_get(page)
  end

  private

  def execute(data, one_login_id = nil)
    token = fetch_access_token
    return unless token.present?

    uri = one_login_id.present? ? build_update_URI(one_login_id) : build_create_URI
    request = one_login_id.present? ? Net::HTTP::Put.new(uri) : Net::HTTP::Post.new(uri)
    request.content_type = 'application/json'
    request['Authorization'] = "bearer:#{token}"
    request.body = JSON.dump(data)

    request_options = { use_ssl: uri.scheme == "https" }

    response = Net::HTTP.start(uri.hostname, uri.port, request_options) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end

  def execute_get(page_no=nil)
    token = fetch_access_token
    return unless token.present?

    uri = build_get_URI(page_no)
    request = Net::HTTP::Get.new(uri)
    request.content_type = 'application/json'
    request['Authorization'] = "bearer:#{token}"

    request_options = { use_ssl: uri.scheme == "https" }

    response = Net::HTTP.start(uri.hostname, uri.port, request_options) do |http|
      http.request(request)
    end

    response
  end

  def build_create_URI
    URI.parse("https://api.#{fetch_region}.onelogin.com/api/1/users")
  end

  def build_update_URI(one_login_id = nil)
    URI.parse("https://api.#{fetch_region}.onelogin.com/api/1/users/#{one_login_id}")
  end

  def build_get_URI(page=nil)
    URI.parse("https://api.#{fetch_region}.onelogin.com/api/1/users?after_cursor=#{page}")
  end
end
