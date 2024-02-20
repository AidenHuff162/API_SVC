class LearningAndDevelopmentIntegrationServices::Lessonly::Endpoint

  def create(integration, data)
    post(integration, 'https://api.lessonly.com/api/v1/users', data)      
  end

  def update(integration, data, lessonly_id)
    put(integration, "https://api.lessonly.com/api/v1/users/#{lessonly_id}", data)
  end

  def archive(integration, lessonly_id)
    put(integration, "https://api.lessonly.com/api/v1/users/#{lessonly_id}/archive")
  end

  def restore(integration, lessonly_id)
    put(integration, "https://api.lessonly.com/api/v1/users/#{lessonly_id}/restore")
  end

  def fetch_users(integration, page)
    get(integration, "https://api.lessonly.com/api/v1/users?page=#{page}")
  end

  private

  def post(integration, endpoint, data)
    HTTParty.post(endpoint,
      body: data,
      headers: { content_type: 'application/json' },
      basic_auth: { username: integration.subdomain, password: integration.api_key }
    )
  end

  def put(integration, endpoint, data = {})
    HTTParty.put(endpoint,
      body: data,
      headers: { content_type: 'application/json' },
      basic_auth: { username: integration.subdomain, password: integration.api_key }
    )
  end

  def get(integration, endpoint)
    HTTParty.get(endpoint,
      headers: { content_type: 'application/json', accept: 'application/json' },
      basic_auth: { username: integration.subdomain, password: integration.api_key }
    )
  end
end