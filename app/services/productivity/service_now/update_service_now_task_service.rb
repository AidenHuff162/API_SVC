# For ServiceNow update ServiceNow task information service
module Productivity
  module ServiceNow
    class UpdateServiceNowTaskService < ApplicationService
      attr_reader :company, :params, :creds_data

      delegate :put_request, :build_create_update_data, :fetch_task_name, :fetch_task_description, 
                :task_user_connection_update_to_string, :log, to: :helper_service

      def initialize(company, params, creds_data, user)
        @company = company
        @params = params
        @creds_data = creds_data
      end

      def call
        update_service_now_task
      end

      private

      def update_service_now_task
        return unless (params &&
          (task = Task.where(id: params, task_type: Task.task_types[:service_now]).take) && 
          (task_user_connections = task.task_user_connections.where.not(service_now_id: nil)))

        task_user_connections.try(:find_each) do |tuc|
          begin
            response = put_request(build_create_update_data(tuc), tuc.service_now_id, creds_data)
            tuc_string = task_user_connection_update_to_string(task, tuc)
            if response.code == 200
              log(company, 'Update Name and Description - Success', tuc_string, response.body, 200)
              ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(company)
            else
              log(company, 'Update Name and Description - Failure', tuc_string, response.body, response.code)
            end
          rescue Exception => exception
            log(company, 'Update Name and Description - Failure', tuc_string, exception.message, 500)
          end
        end
      end

      def helper_service
        Productivity::ServiceNow::Helper.new
      end
    end
  end
end