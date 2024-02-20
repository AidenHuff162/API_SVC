class HrisIntegrationsService::Trinet::Endpoint

	def create(integration, data)
    post(integration, "v1/hire/#{integration.company_code}/employees", data)  
  end

	def update(integration, url, data)
    put(integration, url, data)  
	end

	def generate_access_token(integration)
   	post(integration, 'oauth/accesstoken?grant_type=client_credentials')
	end

	def fetch_options(integration, endpoint)
   	get(integration, endpoint)
	end
	
	private

	def post(integration, endpoint, data = nil)
		url = URI("https://api.trinet.com/#{endpoint}")
		http = Net::HTTP.new(url.host, url.port)
	  http.use_ssl = true
	 	request = Net::HTTP::Post.new(url)
    request.content_type = "application/json"
		
		if data.blank? 
			request.basic_auth(integration.client_id, integration.client_secret)
		elsif integration.access_token.present? && data.present?
    	request["grant_type"] = "client_credentials" 
    	request["Authorization"] = "Bearer #{integration.access_token}" 
    	request.body = JSON.dump(data)
  	end

    response = http.request(request)
	end 	

	def put(integration, endpoint, data)
    url = URI("https://api.trinet.com/#{endpoint}")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Put.new(url)
    request.content_type = "application/json"
    
    if integration.access_token.present? && data.present?
      request["grant_type"] = "client_credentials" 
      request["Authorization"] = "Bearer #{integration.access_token}" 
      request.body = JSON.dump(data)
    end

    response = http.request(request)
	end

	def get(integration, endpoint)
    url = URI("https://api.trinet.com/v1/company/#{integration.company_code}/#{endpoint}")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(url)
    request["Authorization"] = "Bearer #{integration.access_token}" 
    request["grant_type"] = "client_credentials" 
    response = http.request(request)
	end
end
