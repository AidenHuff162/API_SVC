module Api
  module V1
    module Admin
      module WebhookIntegrations
        class WebhookController < ApplicationController
          rescue_from ActiveRecord::RecordNotFound, with: :not_found

          skip_before_action :authenticate_user!, raise: false
          skip_before_action :verify_current_user_in_current_company!, raise: false

          include IntegrationStatisticsManagement

          def current_company
            @current_company ||= request.env['CURRENT_COMPANY']
          end

          def convert_params_to_hash
            params = params.to_h
          end

          def lever_credentials
            current_company
            unless @current_company
              create_webhook_logging(nil, 'Lever', 'Lever Webhook - Company not found', request.env["HTTP_HOST"], 'failed', nil)
              raise ActiveRecord::RecordNotFound
            end
            if @current_company.lever_mapping_feature_flag
              @lever_api_instances = @current_company.integration_instances.where(api_identifier: "lever")
            else
              @lever_api = @current_company.integrations.find_by(api_name: "lever")
            end
          end

          def bamboo_hr_credentials
            current_company
            unless @current_company
              create_webhook_logging(nil, 'BambooHR', 'BambooHR Webhook - Company not found', request.env["HTTP_HOST"], 'failed', nil)
              raise ActiveRecord::RecordNotFound
            end
            @bamboo_api = @current_company.integration_instances.find_by(api_identifier: "bamboo_hr", state: :active)
          end

          def namely_credentials
            current_company
            unless @current_company
              create_webhook_logging(nil, 'Namely','Namely Webhook - Company not found', request.env["HTTP_HOST"], 'failed', nil)
              raise ActiveRecord::RecordNotFound
            end
            @namely_api = @current_company.integration_instances.where(api_identifier: 'namely').first
          end

          def workable_credentials
            current_company
            unless @current_company
              create_webhook_logging(nil, 'Workable', 'Workable Webhook - Company not found', request.env["HTTP_HOST"], 'failed', nil)
              raise ActiveRecord::RecordNotFound
            end
            @workable_api = @current_company.integration_instances.find_by(api_identifier: "workable")
            @workable_api = @workable_api.reload if @workable_api.present?
          end

          def smart_recruiters_credentials
            current_company
            unless @current_company
              create_webhook_logging(nil, 'Smart Recruiters', 'SmartRecruiters Webhook - Company not found', request.env["HTTP_HOST"], 'failed', nil)
              raise ActiveRecord::RecordNotFound
            end
            @smart_recruiters_api = @current_company.integration_instances.find_by(api_identifier: "smart_recruiters") rescue nil
            @smart_recruiters_api.reload if @smart_recruiters_api.present?
          end

          def create_webhook_logging(company, integration_name, action, response_data, status, location, error=nil)
            @webhook_logging ||= LoggingService::WebhookLogging.new
            @webhook_logging.create(company, integration_name, action, response_data, status, location, error)
          end

          def create_integration_logging(company, integration_name, action, request, response, status)
            @integration_logging ||= LoggingService::IntegrationLogging.new
            @integration_logging.create(company, integration_name, action, request, response, status)
          end
        end
      end
    end
  end
end
