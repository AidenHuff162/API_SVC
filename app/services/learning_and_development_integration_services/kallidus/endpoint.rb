class LearningAndDevelopmentIntegrationServices::Kallidus::Endpoint

  def fetch_users(integration, user_query = nil)
    get(integration, 'common-user/v1/users', user_query)
  end

  def update(integration, data, kallidus_learn_id)
    put(integration, 'common-user/v1/users', data, kallidus_learn_id)
  end

  def create(integration, data)
    post(integration, 'suite-user-import/v1/users', data)   
  end

  private

  def get(integration, endpoint, user_query)
    uri = "#{base_url(integration)}/#{endpoint}#{user_query}"
    HTTParty.get(uri, headers: { 'Ocp-Apim-Subscription-Key' => integration.api_key, 'Ocp-Apim-Trace' => 'true' })
  end

  def post(integration, endpoint, data)
    uri = "#{base_url(integration)}/#{endpoint}"
    HTTParty.post(uri,
      body: data.to_json,
      headers: { 'content_type' => 'application/json', 'Ocp-Apim-Subscription-Key' => integration.api_key, 'Ocp-Apim-Trace' => 'true' }
    )
  end

  def put(integration, endpoint, data, kallidus_learn_id)
    uri = "#{base_url(integration)}/#{endpoint}/#{kallidus_learn_id}"
    HTTParty.put(uri,
      body: data.to_json,
      headers: { 'content_type' => 'application/json', 'Ocp-Apim-Subscription-Key' => integration.api_key, 'Ocp-Apim-Trace' => 'true' }
    )
  end

  def base_url(integration)
    (!Rails.env.production? && integration.subdomain.present?) ? "https://#{integration.subdomain}.azure-api.net" : 'https://gateway.kallidusapi.com' 
  end
end