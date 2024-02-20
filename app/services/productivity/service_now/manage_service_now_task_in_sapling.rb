module Productivity
  module ServiceNow
    class ManageServiceNowTaskInSapling < ApplicationService
      attr_reader :company, :integration_instance, :cred_data

      delegate :get_completed_tasks, :log, :fetch_integration, :get_credentials, to: :helper_service

      def initialize(company_id)
        @company = Company.find_by_id(company_id)
        @integration_instance = fetch_integration(company)
        @cred_data = get_credentials(integration_instance)
      end

      def call
        update_service_now_task_in_sapling
      end

      private

      def update_service_now_task_in_sapling
        return unless integration_instance.present?
        begin
          response = get_completed_tasks(cred_data)
          if response.code == 200
            data = JSON.parse(response.body)['result']
            if data.length > 0
              tasks_data_hash = data.map {|m| [m['sys_id'], m['closed_at']]}.to_h
              TaskUserConnection.having_company(company.id).where.not(state: 'completed').where(service_now_id: tasks_data_hash.keys).each do |tuc|
                completed_at = tasks_data_hash[tuc.service_now_id.to_s]
                tuc.update(state: 'completed', completed_by_method: TaskUserConnection.completed_by_methods[:service_now], completed_at: completed_at)
              end
            end
          end
        rescue Exception => exception
          log(company, 'Complete Task From ServiceNow - Failure', nil, exception.message, 500)
        end
      end

      def helper_service
        Productivity::ServiceNow::Helper.new
      end
    end
  end
end
