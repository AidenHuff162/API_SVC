require 'net/http'
require 'uri'
require 'json'

class CompanyAttributesSyncService::Helper

  def perform_curl_request end_point, request_payload
    uri = URI.parse(end_point)
    Net::HTTP.start(uri.hostname, uri.port, get_request_options(uri)) { |http| http.request(get_request(request_payload, uri)) }
  end

  def get_request request_payload, uri
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/json'
    request.body = request_payload
    request
  end

  def get_request_options uri
    { use_ssl: uri.scheme == 'https' }
  end

  def common_properties company
    active_integrations = company.active_integration_names
    integration_names = active_integrations.join(', ') 
    {
      subdomain: company.subdomain,
      pto_addon: company.enabled_time_off,
      account_type: company.account_type,
      total_people: company.users.not_incomplete.count,
      account_state: company.account_state,
      active_people: company.users.active.count,
      surveys_addon: company.surveys_enabled,
      calendar_addon: company.enabled_calendar,
      org_chart_addon: company.enabled_org_chart,
      locations_count: company.locations.count,
      integration_names:  integration_names.present? ? integration_names : 'null',
      track_approve_addon: company.enable_custom_table_approval_engine,
      active_integrations_count: active_integrations.size
    }
  end

  def create_loggings e_message, company
    LoggingService::GeneralLogging.new.create(
      company,
      'Heap Sync Company Data', 
      {error: e_message}
    )
  end
end