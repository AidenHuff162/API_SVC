class AsanaService::DestroyTask

  def initialize(tuc)
    @tuc = tuc
    @company = @tuc.user.company rescue nil
    @integration = @company.integration_instances.find_by(api_identifier: "asana", state: :active) rescue nil
  end

  def perform
    return unless @tuc.present? && @tuc.task_id.present? && @company.present? && @integration.present?
    # complete task on asana
    url = URI::encode("https://app.asana.com/api/1.0/tasks/#{@tuc.asana_id}")

    deleted_task = execute_request(url)

    if !deleted_task
      log('Destroy Task - ERROR', 500, "Could not destroy task in Asana: id = #{@tuc.id}")
    elsif deleted_task["errors"].present?
      log('Destroy Task - ERROR', 500, {errors: deleted_task["errors"], tuc_id: @tuc.id})
    end
    @tuc.asana_id = nil
    @tuc.save!

    ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(@company)
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
