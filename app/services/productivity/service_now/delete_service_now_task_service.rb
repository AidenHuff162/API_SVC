module Productivity
  module ServiceNow
    class DeleteServiceNowTaskService < ApplicationService
      attr_reader :company, :params, :creds_data

      delegate :delete_request, :log, to: :helper_service

      def initialize(company, params, creds_data, user)
        @company = company
        @params = params
        @creds_data = creds_data
      end

      def call
        destroy_service_now_task
      end

      private

      def destroy_service_now_task
        return unless params.present?
        begin
          response = delete_request(params, creds_data)
          log_body = (response.code == 204) ? 'Done' : response.body
          log(company, 'Delete', params, log_body, response.code)
        rescue Exception => exception
          log(company, 'Delete', nil, exception.message, 500)
          slack_text = I18n.t('slack_notifications.service_now.deleted', issue_id: params, company_name: company.name)
          SlackNotificationJob.perform_later(company.id, {text: slack_text})
        end
      end

      def helper_service
        Productivity::ServiceNow::Helper.new
      end
    end
  end
end
