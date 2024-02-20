class AsanaService::CompleteTask

  def initialize(tuc)
    @tuc = tuc
    @company = @tuc.user.company rescue nil
    @integration = @company.integration_instances.find_by(api_identifier: "asana", state: :active) rescue nil
  end

  def perform
    return unless @tuc.present? && @tuc.task_id.present? && @company.present? && @integration.present?
    # complete task on asana
    url = URI::encode("https://app.asana.com/api/1.0/tasks/#{@tuc.asana_id}")
    task_data = { data: {
      completed: true
    }}

    updated_task = execute_request(url, task_data)

    if !updated_task
      log('Complete Task - ERROR', 500, "Could not complete task in Asana: id = #{@tuc.id}")
    elsif updated_task["errors"].present?
      log('Complete Task - ERROR', 500, {errors: updated_task["errors"], tuc_id: @tuc.id})
    else
      @tuc.asana_id = nil
      @tuc.save!

      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(@company)
    end
    true
  end

  private

  def execute_request(url, post_data = nil)
    url = URI(url) rescue nil
    return false unless url.present?
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Put.new(url)
    request.body = JSON.dump(post_data)

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
