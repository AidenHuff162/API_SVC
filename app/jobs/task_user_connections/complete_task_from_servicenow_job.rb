module TaskUserConnections
  class CompleteTaskFromServicenowJob < ApplicationJob
    queue_as :receive_tasks_from_service_now

    def perform
      Company.active_companies.joins(:integration_instances).where(integration_instances: { api_identifier: 'service_now' }).ids.each do |company_id|
        ::Productivity::ServiceNow::ManageServiceNowTaskInSapling.call(company_id)
      end
    end
  end
end
