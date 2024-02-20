module Api
  module V1
    module Webhook
      class LinkedInController < ApplicationController
        skip_before_action :authenticate_user!, raise: false
        skip_before_action :verify_current_user_in_current_company!, raise: false

        before_action :decrypt_data, only: [:onboard]
        before_action :validate_company, only: [:callback]
        before_action :find_company_by_subdomain, only: [:onboard]
        before_action :initialize_service

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 401
        end

        def callback
          status = 200
          data = {}

          if @linked_in_service.validate_callback_signature request.headers['HTTP_X_LI_SIGNATURE']
            @linked_in_service.manage_pending_hire
            @linked_in_service.linked_in_integration.update_column(:synced_at, DateTime.now) if @linked_in_service.linked_in_integration.present?
          else
            status = 400
            data = { 'errorMessage': I18n.t('linked_in.missing_fields')}
          end

          render json: data, status: status
        end

        def onboard
          @linked_in_service.validate_onboarding_signature
          if Rails.env.production?
            redirect_to "https://#{@current_company.app_domain}/#/admin/settings/integrations?source=linked_in&redirect_url="+params['redirectUrl']+"&hiringContext=#{params['hiringContext']}&map=linkedin"
          else
            redirect_to "http://#{@current_company.app_domain}/#/admin/settings/integrations?source=linked_in&redirect_url="+params['redirectUrl']+"&hiringContext=#{params['hiringContext']}&map=linkedin"
          end
         end

        private

        def initialize_service
          @linked_in_service = AtsIntegrationsService::LinkedIn.new(@current_company, params)
        end

        def validate_company
          raise CanCan::AccessDenied unless fetch_company
        end

        def fetch_company
          IntegrationCredential.joins(:integration_instance).where(name: 'Hiring Context', integration_instances: {api_identifier: 'linked_in', state: :active}).find_each do |integration|
            @current_company = integration.integration_instance&.company if integration.hiring_context == params['hiringContext']
          end
        end

        def find_company_by_subdomain
          @current_company = Company.find_by_subdomain(params[:subdomain][:payload]) if params[:subdomain][:payload].present?
          redirect_to "https://www.kallidus.com/sapling-hr" unless @current_company
        end

        def decrypt_data
          begin
            params.merge!(JsonWebToken.decode(params['data']))
            params.merge!(subdomain: JsonWebToken.decode(params['subdomain']))
          rescue
            raise CanCan::AccessDenied
          end
        end
      end
    end
  end
end
