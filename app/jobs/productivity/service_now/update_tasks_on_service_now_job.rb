# For ServiceNow update ServiceNow task job
module Productivity
  module ServiceNow
    class UpdateTasksOnServiceNowJob < ApplicationJob
      queue_as :default

      def perform(company_id, param)
        Productivity::ServiceNow::ManageSaplingTaskInServiceNow.new(nil, company_id, param).perform('update')
      end
    end
  end
end
