class AsanaService::DeleteWebhook

  def initialize(tuc)
    @tuc = tuc
    @company = @tuc.user.company rescue nil
    @integration = @company.integration_instances.find_by(api_identifier: "asana", state: :active) rescue nil
  end

  def perform
    return unless @tuc.present? && @company.present? && @integration.present? && @tuc.asana_webhook_gid.present?
    # delete webhook on asana
    url = URI::encode("https://app.asana.com/api/1.0/webhooks/#{@tuc.asana_webhook_gid}")

    deleted_webhook = execute_request(url)

    if !deleted_webhook
      log('Delete Webhook - ERROR', 500, "Could not delete webhook in Asana: id = #{@tuc.id}")
    elsif deleted_webhook["errors"].present?
      log('Delete Webhook - ERROR', 500, {errors: deleted_webhook["errors"], tuc_id: @tuc.id})
    end
    true
  end

  private

  def execute_request(url)
    url = URI(url) rescue nil
    return false unless url.present?
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Delete.new(url)

    request["Accept"] = "application/json"
    request["content-type"] = "application/json"
    request["Authorization"] = "Bearer #{@integration.asana_personal_token}"

    response = http.request(request)
    JSON.parse(response.read_body)
  end

  def log(action, status, response, request = nil)
    LoggingService::IntegrationLogging.new.create(@company, 'Asana', action, request, response, status)
  end
end
