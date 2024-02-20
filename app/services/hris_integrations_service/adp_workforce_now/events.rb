class HrisIntegrationsService::AdpWorkforceNow::Events

  def change_string_custom_field_event(params, access_token, certificate)
    faraday_connection_adapter(certificate).post 'events/hr/v1/worker.custom-field.string.change' do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['accept'] = 'application/json'
      req.headers['authorization'] = "Bearer #{access_token}"
      req.body = params.to_json
    end  
  end

  def faraday_connection_adapter(certificate)
    Faraday.new 'https://api.adp.com/', :ssl => {
      :client_cert  => certificate&.cert,
      :client_key   => certificate&.key,
    }
  end
end