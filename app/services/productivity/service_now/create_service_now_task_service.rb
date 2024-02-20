module Productivity
  module ServiceNow
    class CreateServiceNowTaskService < ApplicationService
      attr_reader :company, :params, :user, :creds_data

      delegate :post_request, :build_create_update_data, :fetch_task_name, :fetch_task_description, 
                :task_user_connection_create_to_string, :log, to: :helper_service

      def initialize(company, params, creds_data, user)
        @company = company
        @user = user
        @params = params
        @creds_data = creds_data
      end

      def call
        return unless params.present? && user.present?
        begin
          tasks_count = 0
          TaskUserConnection.unassigned_service_now_tasks(params, user.id).try(:find_each) do |tuc|
            begin
              if tuc.before_due_date.nil? || (tuc.before_due_date.in_time_zone(user.company.time_zone) < Time.now)
                tasks_count += (create_service_now_task(tuc, user) ? 1 : 0)
              else
                Productivity::ServiceNow::CreateTaskOnServiceNowJob.perform_at(tuc.before_due_date.in_time_zone(user.company.time_zone), user.id, user.company.id, tuc.id)
              end
            rescue Exception => exception
              log(user.company, 'Create', task_user_connection_create_to_string(tuc), exception.message, 500)
            end
          end
          send_notifications(user, tasks_count) if tasks_count > 0
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(user.company)
        rescue Exception => exception
          rescue_create_operation({user_id: user.id, tucs: params.inspect}, exception.message)
        end
      end
      
      private

      def create_service_now_task(tuc, user)
        begin
          pay_load = build_create_update_data(tuc)
          response = post_request(pay_load, creds_data)
          if response.code == 201
            body = JSON.parse(response.body)
            tuc.update!(service_now_id: body['result']['sys_id'])
            log(user.company, 'Create', task_user_connection_create_to_string(tuc), 'Done', 201)
            return true
          else
            log(user.company, 'Create', task_user_connection_create_to_string(tuc), "Errors #{ body['result']}", 500)
          end
        rescue StandardError => exception
          rescue_create_operation(task_user_connection_create_to_string(tuc), exception.message)
        end
      end

      def send_notifications(user, tasks_count)
        history_description = I18n.t('history_notifications.service_now.created', translation_history_params(tasks_count, user))
        History.create_history(history_params(user, history_description))
      end

      def translation_history_params(tasks_count, user)
        {
          task_count: tasks_count, 
          full_name: user.full_name, 
          current_stage: user.current_stage
        }
      end

      def history_params(user, description)
        {
          company: user.company,
          description: description,
          attached_users: [user.id],
          created_by: History.created_bies[:system],
          event_type: History.event_types[:integration],
          integration_type: History.integration_types[:service_now]
        }
      end

      def rescue_create_operation(error_request, msg)
        slack_msg = I18n.t('slack_notifications.service_now.created', company_name: user.company.name, full_name: user.full_name)
        SlackNotificationJob.perform_later(user.company.id, { username: user.full_name, text: slack_msg })
        log(user.company, 'Create', error_request, { message: msg }, 500)
      end

      def helper_service
        Productivity::ServiceNow::Helper.new
      end
    end
  end
end
