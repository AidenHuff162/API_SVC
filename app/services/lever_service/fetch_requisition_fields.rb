class LeverService::FetchRequisitionFields

  def initialize(company)
    @company = company
    if @company.lever_mapping_feature_flag
      @api_key = @company.integration_instances.where(api_identifier: "lever").take.api_key rescue nil
    else
      @api_key = @company.integrations.find_by(api_name: "lever").api_key rescue nil
    end
  end

  def perform
    return [] unless @company.present? && @api_key.present?
    if Rails.env.staging?
      lever_webhook_resource = RestClient::Resource.new "https://api.sandbox.lever.co/v1/requisition_fields", "#{@api_key}", ''
    else
      lever_webhook_resource = RestClient::Resource.new "https://api.lever.co/v1/requisition_fields", "#{@api_key}", ''
    end
    begin
      if Rails.env.staging?
        response = JSON.parse(lever_webhook_resource.get())
      else
        response = JSON.parse(lever_webhook_resource.get({x_lever_client_id: ENV['LEVER_X_CLIENT_ID']}))
      end
    rescue Exception => e
      if [RestClient::Unauthorized, RestClient::Forbidden].include?(e.class)
        return [[], 403]
      else
        return [[], 500]
      end
    end
    return [(response["data"] || []), 200]
  end

end
