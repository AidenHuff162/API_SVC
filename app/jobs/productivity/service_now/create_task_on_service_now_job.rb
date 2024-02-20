# For ServiceNow create ServiceNow task job
module Productivity
  module ServiceNow
    class CreateTaskOnServiceNowJob
      include Sidekiq::Worker
      sidekiq_options queue: :default, retry: true, backtrace: true

      def perform(user_id, company_id, param)
        Productivity::ServiceNow::ManageSaplingTaskInServiceNow.new(user_id, company_id, param).perform('create')
      end
    end
  end
end
