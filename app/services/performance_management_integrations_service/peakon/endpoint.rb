class PerformanceManagementIntegrationsService::Peakon::Endpoint

  def create(integration, data)
    post(integration, "scim/v2/Users", data)	  	
  end

  def delete(integration, user)
    HTTParty.delete("https://api.peakon.com/scim/v2/Users/#{user.peakon_id}",
      headers: { authorization: "Bearer #{integration.access_token}" }
    )
  end	

  def update(integration, data, user)
    put(integration, "scim/v2/Users/#{user.peakon_id}", data)
  end

  private

  def post(integration, endpoint, data = nil)
    uri = URI("https://api.peakon.com/#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri)

    if data.present?
      return unless integration.access_token.present?
      request.content_type = 'application/scim+json'
      request['Authorization'] = "Bearer #{integration.access_token}"
      request.body = data.to_json
    end
    http.request(request)
  end

  def put(integration, endpoint, data)
    HTTParty.put("https://api.peakon.com/#{endpoint}",
      body: data,
      headers: { accept: 'application/scim+json', content_type: 'application/scim+json', authorization: "Bearer #{integration.access_token}" }
    )
  end 
end