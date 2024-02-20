module Api
  module V1
    module Admin
      module WebhookIntegrations
        class SmartRecruitersController < WebhookController

          before_action :current_company, :smart_recruiters_credentials, except: :smart_recruiters_authorize
          before_action :create_smart_recruiters_credentials, only: :authenticate
          before_action :find_current_company_and_smart_recruiters_credentials, only: :smart_recruiters_authorize

          include JsonResponder
          respond_to :json
          responders :json

          def authenticate
            if @smart_recruiters_api.present? && @smart_recruiters_api.client_secret.present? && @smart_recruiters_api.client_id.present?
              redirect_to prepare_authetication_url
            end
          end

          def smart_recruiters_authorize
            code = params[:code]
            response = ""
   
            if params['error'] && params['error'] == 'access_denied'
              response = 'access_denied'
            else
              create_webhook_logging(@current_company, 'Smart Recruiters', 'Retrieve Code', { request: "https://www.smartrecruiters.com/identity/oauth/allow?client_id=#{@smart_recruiters_api.client_id}&redirect_uri=https://#{@current_company.domain}/api/v1/admin/webhook_integrations/smart_recruiters/smart_recruiters_authorize&scope=candidates_read%20jobs_read%20company_read", code: code }, 'succeed', nil)
              smart_recruiters = AtsIntegrations::SmartRecruiters.new(@current_company, @smart_recruiters_api, code)
              response = smart_recruiters.retrieve_authorization_token
            end


            if Rails.env.production?
              redirect_to "https://#{@current_company.app_domain}/#/admin/settings/integrations?response=#{response}"
            else
              redirect_to "http://#{@current_company.app_domain}/#/admin/settings/integrations?response=#{response}"
            end
           end

          def import
            response = {}
            response = { error: "token_missing" } if !@smart_recruiters_api.access_token.present?
            if @smart_recruiters_api.present? && @smart_recruiters_api.client_secret.present? && @smart_recruiters_api.client_id.present? && @smart_recruiters_api.access_token.present? && @smart_recruiters_api.expires_in.present? && @smart_recruiters_api.refresh_token.present?
              ImportPendingHiresFromSmartRecruitersJob.perform_later(current_company.id)
            end
            respond_with response.to_json
          end

          def server_response
            puts "--------------\n"*23
            puts "Server Response: #{params.inspect}"
            respond_with true.to_json
          end

          private

          def create_smart_recruiters_credentials
            @smart_recruiters_api = current_company.integrations.create!(client_secret: ENV['SMART_RECRUITER_CLIENT_SECRET'], client_id: ENV['SMART_RECRUITER_CLIENT_ID'], api_name: 'smart_recruiters') if !@smart_recruiters_api.present?
          end

          def find_current_company_and_smart_recruiters_credentials
            begin 
              ids = JsonWebToken.decode(params[:state])
              @current_company = Company.find_by(id: ids["company_id"].to_i)
              @smart_recruiters_api = @current_company.integration_instances.find_by(id: ids["instance_id"].to_i)
              raise CanCan::AccessDenied unless @smart_recruiters_api.present?
            rescue Exception => e
              raise CanCan::AccessDenied
            end
          end


          def prepare_authetication_url
            state = JsonWebToken.encode({company_id: current_company.id, instance_id: @smart_recruiters_api.id})
            "https://www.smartrecruiters.com/identity/oauth/allow?client_id=#{@smart_recruiters_api.client_id}&redirect_uri=https://www.saplingapp.io/smart_recruiters_authorize&scope=candidates_read%20jobs_read%20company_read&state=#{state}"
          end
        end
      end
    end
  end
end
