module Productivity
  module ServiceNow
    class UpdateStatusServiceNowTaskService < ApplicationService
      attr_reader :company, :params, :creds_data

      delegate :put_request, :build_update_state_data, :task_user_connection_update_to_string, :log, :get_credentials, to: :helper_service

      def initialize(company, params, creds_data, user)
        @company = company
        @params = params
        @creds_data = creds_data
      end

      def call
        update_service_now_task_state
      end

      private

      def update_service_now_task_state
        return unless (params && 
          (task_user_connection = TaskUserConnection.find_by(id: params)) &&
          (task = Task.find_by(id: task_user_connection.task_id, task_type: Task.task_types[:service_now])))

        begin
          response = put_request(build_update_state_data, task_user_connection.service_now_id, creds_data)
          tuc_string = task_user_connection_update_to_string(task, task_user_connection)
          if response.code == 200
            log(company, 'Update task state - Success', tuc_string, response.body, 200)
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(company)
          else
            log(company, 'Update task state - Failure', tuc_string, response.body, response.code)
          end
        rescue Exception => exception
          log(company, 'Update task state - Failure', tuc_string, exception.message, 500)
        end
      end

      def helper_service
        Productivity::ServiceNow::Helper.new
      end
    end
  end
end