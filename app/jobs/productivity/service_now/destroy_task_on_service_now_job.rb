# For ServiceNow destroy ServiceNow task job
module Productivity
  module ServiceNow
    class DestroyTaskOnServiceNowJob < ApplicationJob
      queue_as :default

      def perform(company_id, param)
        Productivity::ServiceNow::ManageSaplingTaskInServiceNow.new(nil, company_id, param).perform('delete')
      end
    end
  end
end