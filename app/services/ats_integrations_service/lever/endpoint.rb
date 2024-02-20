class AtsIntegrationsService::Lever::Endpoint

  @@opportunities_base_url ||= Rails.env.staging? ? 'https://api.sandbox.lever.co/v1' : 'https://api.lever.co/v1'

  def lever_webhook_endpoint(opportunity_id, api_key, data_url = nil)
    opportunity_base_url = @@opportunities_base_url + '/opportunities/'
    fetch_data(RestClient::Resource.new "#{opportunity_base_url}#{opportunity_id}#{data_url}", "#{api_key}", '')
  end

  def lever_archived_webhook_endpoint(archive_reason_base_url, api_key)
    fetch_data(RestClient::Resource.new "#{@@opportunities_base_url}#{archive_reason_base_url}", "#{api_key}", '')
  end

  def lever_user_webhook_endpoint(user_id, api_key)
    fetch_data(RestClient::Resource.new "#{@@opportunities_base_url}/users/#{user_id}", "#{api_key}", '')
  end

  def lever_posting_webhook_endpoint(posting_id, api_key)
    fetch_data(RestClient::Resource.new "#{@@opportunities_base_url}/postings/#{posting_id}", "#{api_key}", '')
  end

  def lever_requisitions_webhook_endpoint(requisition_id, api_key)
    fetch_data(RestClient::Resource.new "#{@@opportunities_base_url}/requisitions/#{requisition_id}", "#{api_key}", '')
  end

  private

  def fetch_data(resource)
    Rails.env.staging? ? JSON.parse(resource.get()) : JSON.parse(resource.get({x_lever_client_id: ENV['LEVER_X_CLIENT_ID']}))
  end
end
