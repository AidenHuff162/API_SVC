module Productivity
  module ServiceNow
    class ManageSaplingTaskInServiceNow
      attr_reader :user, :company, :integration, :creds_data, :params

      delegate :fetch_integration, :log, :get_credentials, to: :helper_service

      def initialize(user_id, company_id, params)
        @params = params
        @company = Company.find(company_id)
        @user = company.users.find_by_id(user_id)
        @integration = fetch_integration(company)
        @creds_data = get_credentials(integration)
      end

      def perform(action)
        begin
          if integration.nil? or !creds_data.values.all?
            log(company, action.titleize, nil, {message: 'Unable to get credentials'}, 404)
            return
          end
          manage_task(action)
          integration.update_column(:synced_at, DateTime.now)
        rescue Exception => e
          log(company, action.titleize, nil, e.message, 404)
        end
      end

      private

      def helper_service
        Productivity::ServiceNow::Helper.new
      end

      def manage_task(action)
        "Productivity::ServiceNow::#{action.titleize.gsub(' ', '')}ServiceNowTaskService".constantize.call(company, params, creds_data, user)
      end
    end
  end
end
