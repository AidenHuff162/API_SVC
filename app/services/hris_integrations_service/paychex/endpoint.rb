class HrisIntegrationsService::Paychex::Endpoint

	def create(integration, data)
    post(integration, "companies/#{integration.company_code}/workers", data)	  	
  end

	def update(integration, paychex_id, data)
		patch(integration, "workers/#{paychex_id}", data)	  	
	end
	# :nocov:
	def fetch_job_titles(integration)
		get(integration, "companies/#{integration.company_code}/jobtitles")
	end

	def fetch_locations(integration)
		get(integration, "companies/#{integration.company_code}/locations")
	end
	# :nocov:
	def fetch_options(integration, endpoint)
		get(integration, "companies/#{integration.company_code}/#{endpoint}")
	end

	def generate_access_token(integration)
		uri = URI("#{fetch_paychex_api_path(integration.subdomain)}auth/oauth/v2/token")
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		request = Net::HTTP::Post.new(uri)
		request.content_type = 'application/x-www-form-urlencoded'
		request.body = "grant_type=client_credentials&client_id=#{integration.client_id}&client_secret=#{integration.client_secret}"
		http.request(request)
	end

	private

	def post(integration, endpoint, data = nil)
		uri = URI("#{fetch_paychex_api_path(integration.subdomain)}#{endpoint}")
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		request = Net::HTTP::Post.new(uri)

		if data.present?
			return unless integration.access_token.present?
			request.content_type = 'application/json'
			request['Authorization'] = "Bearer #{integration.access_token}"
			request.body = data.to_json
		end
		
		http.request(request)
	end

	def patch(integration, endpoint, data)
		return unless integration.access_token.present?

		response = HTTParty.patch("#{fetch_paychex_api_path(integration.subdomain)}#{endpoint}",
		  	body: data.to_json,
		 	headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{integration.access_token}" }
		)
	end

	def get(integration, endpoint)
		return unless integration.access_token.present?
		
		response = HTTParty.get("#{fetch_paychex_api_path(integration.subdomain)}#{endpoint}",
		  headers: { 'Accept' => 'application/json', 'Authorization' => "Bearer #{integration.access_token}" }
		)
	end

    def fetch_paychex_api_path(subdomain); subdomain == 'n1' ? 'https://api.n1.paychex.com/' : 'https://api.paychex.com/' end
end
