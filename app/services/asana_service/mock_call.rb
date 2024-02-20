class AsanaService::MockCall

  def initialize(integration)
    @integration = integration
    @company = integration.company
    integration_credentials_hash = integration.integration_credentials.map{ |cred| [cred.name, cred.value] }.to_h
    @asana_personal_token, @asana_organization_id = integration_credentials_hash.values_at('Asana Personal Token', 'Asana Organization ID')
  end

  def perform
    return false unless @company && @integration && @asana_personal_token && @asana_organization_id
    # TODO perform mock api call, return true if 200 response TODO
    url = URI("https://app.asana.com/api/1.0/users?limit=1&workspace=#{@asana_organization_id}")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)
    request["content-type"] = "application/json"
    request["Authorization"] = "Bearer #{@asana_personal_token}"

    response = http.request(request)
    response_hash = JSON.parse(response.read_body)

    if response_hash["errors"].present?
      return response_hash["errors"]
    else
      return true
    end
  end

end
