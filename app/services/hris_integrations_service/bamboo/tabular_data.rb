class HrisIntegrationsService::Bamboo::TabularData < HrisIntegrationsService::Bamboo::Initializer

  def initialize(company)
    super(company)
  end

  def fetch(table_name, bamboo_id)
    return if !bamboo_api_initialized?

    response = HTTParty.get("https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/employees/#{bamboo_id}/tables/#{table_name}/", 
      headers: { accept: "application/json" }, 
      basic_auth: { username: bamboo_api.api_key, password: 'x' }
      )

    JSON.parse(response.body)
  end

  def fetch_custom(table_name, bamboo_id)
    return if !bamboo_api_initialized?

    response = HTTParty.get("https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/employees/#{bamboo_id}/tables/#{table_name}", 
      headers: { accept: "application/xml" }, 
      basic_auth: { username: bamboo_api.api_key, password: 'x' }
      )

    hash = Hash.from_xml(response)
    if hash["table"]['row'].instance_of? Hash
      return hash["table"]['row']['field'] rescue {}
    else
      return hash["table"]['row'].last['field'] rescue {}
    end
  end

  def create_or_update(action, table_name, bamboo_id, params)
    return if !bamboo_api_initialized?

    begin
      # id = fetch(table_name, bamboo_id).last['id'] rescue ""
      response = HTTParty.post("https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/employees/#{bamboo_id}/tables/#{table_name}",
        body: params, 
        headers: { content_type: "text/html" }, 
        basic_auth: { username: bamboo_api.api_key, password: 'x' }
        )

      log("#{action} - Success (ROW-ID:)", {request: params}, {response: response}, 200)
    rescue Exception => exception
      log("#{action} - Failure", {request: params}, {response: exception.message}, 500)
    end
  end

  def create_or_update_custom(action, table_name, bamboo_id, params)
    return if !bamboo_api_initialized?

    begin
      response = HTTParty.post("https://api.bamboohr.com/api/gateway.php/#{bamboo_api.subdomain}/v1/employees/#{bamboo_id}/tables/#{table_name}",
        body: params, 
        headers: { content_type: "text/html" }, 
        basic_auth: { username: bamboo_api.api_key, password: 'x' }
        )

      log("#{action} - Success", {request: params}, {response: response}, 200)
    rescue Exception => exception
      log("#{action} - Failure", {request: params}, {response: exception.message}, 500)
    end
  end
end
