class LearningAndDevelopmentIntegrationServices::LearnUpon::Endpoint

  def create(integration, data)
    post(integration, "api/v1/users", data)      
  end

  def update(integration, data, learn_upon_id)
    put(integration, "api/v1/users", data, learn_upon_id)
  end

  def fetch_user(integration, query)
    get(integration, "api/v1/users/#{query}", query)
  end

  def fetch_users(integration)
    get(integration, "api/v1/users")
  end

  private

  def post(integration, endpoint, data)
    uri = "https://#{integration.subdomain}.learnupon.com/#{endpoint}"
    
    HTTParty.post(uri,
      body: data,
      headers: { content_type: 'application/json' },
      basic_auth: { username: integration.username, password: integration.password }
    )
  end

  def put(integration, endpoint, data, learn_upon_id)
    uri = "https://#{integration.subdomain}.learnupon.com/#{endpoint}/#{learn_upon_id}"
    
    HTTParty.put(uri,
      body: data,
      headers: { content_type: 'application/json' },
      basic_auth: { username: integration.username, password: integration.password }
    )
  end

  def get(integration, endpoint)
    uri = "https://#{integration.subdomain}.learnupon.com/#{endpoint}"

    HTTParty.get(uri,
      headers: { content_type: 'application/json', accept: 'application/json' },
      basic_auth: { username: integration.username, password: integration.password }
    )
  end
end