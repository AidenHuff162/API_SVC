class AtsIntegrationsService::Fountain::Endpoint
  
  require 'uri'
  require 'net/http'
  require 'openssl'

  @@base_url ||= Rails.env.staging? || Rails.env.development? ? "https://partners-sandbox.fountain.com/v1" : "https://partners-api.fountain.com/v1"

  def update_partner(applicant_id, data)
    partner_id = ENV['FOUNTAIN_PARTNER_ID']
    url = "#{@@base_url}/partners/#{partner_id}/applicants/#{applicant_id}/status"
    post(url, data)
  end

  private

  def post(uri, data)
    url = URI(uri)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(url)
    request["Accept"] = 'application/json'
    request["Content-Type"] = 'application/json'
    request["X-ACCESS-TOKEN"] = ENV['FOUNTAIN_API_KEY']
    request.body = data.to_json
    response = http.request(request)
  end
end
