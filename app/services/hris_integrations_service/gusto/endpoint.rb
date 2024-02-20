class HrisIntegrationsService::Gusto::Endpoint

  delegate :vendor_domain, to: :helper_service

  def create_user(integration, data, company_code)
    post(integration, "v1/companies/#{company_code}/employees", data)	  	
  end

  def update_user(integration, data, employee_id)
    put(integration, "v1/employees/#{employee_id}", data)
  end

  def create_user_job(integration, employee_id, data)
    post(integration, "v1/employees/#{employee_id}/jobs", data)
  end

  def update_user_home_address(integration, employee_id, data )
    put(integration, "v1/employees/#{employee_id}/home_address", data)
  end

  def update_user_job(integration, job_id, data)
    put(integration, "v1/jobs/#{job_id}", data)
  end

  def get_gusto_company(integration)
    get(integration, "v1/companies")
  end

  def get_gusto_employee(integration, employee_id)
    get(integration, "v1/employees/#{employee_id}")
  end

  def terminate_user(integration, employee_id, data)
    post(integration, "v1/employees/#{employee_id}/terminations", data)
  end

  def get_gusto_company_location(integration, company_code)
    get(integration, "v1/companies/#{company_code}/locations")
  end

  def update_user_compensation(integration, compensation_id, data)
    put(integration, "/v1/compensations/#{compensation_id}", data)
  end

  def fetch_users(integration)
    get(integration, "/v1/companies/#{integration.company_code}/employees")
  end

  private

  def post(integration, endpoint, data = nil)
    uri = URI("https://#{vendor_domain}/#{endpoint}")
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

  def put(integration, endpoint, data)
    HTTParty.put("https://#{vendor_domain}/#{endpoint}",
      body: data,
      headers: { accept: 'application/json', content_type: 'application/json', authorization: "Bearer #{integration.access_token}" }
    )
  end 

  def get(integration, endpoint)
    HTTParty.get("https://#{vendor_domain}/#{endpoint}",
      headers: { accept: 'application/json', content_type: 'application/json', authorization: "Bearer #{integration.access_token}" }
    )
  end

  private

  def helper_service
    HrisIntegrationsService::Gusto::Helper.new
  end
end
