class AsanaService::SyncTasks

  def perform
    # TODO remove this file if unused after moving to webhook task completion model
    IntegrationInstance.where(api_identifier: "asana").where.not(company_id: nil).includes(:company).each do |integration|
      company = integration.company
      TaskUserConnection.joins(task: :workstream).where(workstreams: {company_id: company.id}, task_user_connections: {state: "in_progress"}, tasks: {survey_id: nil}).where.not(task_user_connections: { asana_id: nil, owner_id: nil}).find_each do |tuc|
        url = URI::encode("https://app.asana.com/api/1.0/tasks/#{tuc.asana_id}")
        asana_task = execute_request(url, integration.asana_personal_token)

        if asana_task.present? && !asana_task["errors"].present? && asana_task["data"]["completed"]
          tuc.state = "completed"
          tuc.asana_id = nil
          tuc.completed_by_method = TaskUserConnection.completed_by_methods[:asana]
          tuc.save!
          tuc.activities.create!(agent_id: tuc.owner.id, description: "completed the task in asana")
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(company)
        end
      end
      integration.update_column(:synced_at, DateTime.now)
    end

  end

  private

  def execute_request(url, token)
    url = URI(url) rescue nil
    return false unless url.present?
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)

    request["Accept"] = "application/json"
    request["content-type"] = "application/json"
    request["Authorization"] = "Bearer #{token}"

    response = http.request(request)
    JSON.parse(response.read_body)
  end

end
