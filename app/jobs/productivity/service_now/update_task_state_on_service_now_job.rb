module Productivity
  module ServiceNow
    class UpdateTaskStateOnServiceNowJob < ApplicationJob
      queue_as :default

      def perform(company_id, param)
        Productivity::ServiceNow::ManageSaplingTaskInServiceNow.new(nil, company_id, param).perform('update_status')
      end
    end
  end
end
