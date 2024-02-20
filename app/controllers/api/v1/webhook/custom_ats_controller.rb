module Api
  module V1
    module Webhook
      class CustomAtsController < ApplicationController
        #custom integrations who use our endpoint as post request i.e. BreezyHR
        include ActionController::HttpAuthentication::Token::ControllerMethods

        skip_before_action :authenticate_user!, raise: false
        skip_before_action :verify_current_user_in_current_company!, raise: false
        
        before_action :validate_source
        before_action :require_company!
        before_action :initialize_service

        rescue_from CanCan::AccessDenied do |exception|
          render body: { message: 'Authentication failure' }, status: 401
        end

        def authenticate
          authenticate_or_request_with_http_token do |api_token, options|
            render json: @custom_ats_service.authenticate(api_token), status: 200
          end
        end

        def create
          authenticate_or_request_with_http_token do |api_token, options|
            result = @custom_ats_service.create(api_token)
            render json: result, status: result[:status]
          end
        end

        private

        def custom_ats_permitted_params
          params.permit(:source, :first_name, :last_name, :preferred_name, :title, :personal_email, :state, :employee_type, :start_date,
            :location, :department, :manager_email).to_h
        end
        
        def current_company
          @current_company ||= request.env['CURRENT_COMPANY']
        end

        def require_company!
          raise CanCan::AccessDenied unless current_company && current_company.active?
        end

        def initialize_service
          @custom_ats_service = ::AtsIntegrationsService::CustomAts.new(@current_company, custom_ats_permitted_params)
        end

        def validate_source
          raise CanCan::AccessDenied unless ['breezy'].include?(params.to_h[:source])
        end
      end
    end
  end
end