module Api
  module V1
    module Webhook
      class HireBridgeController < ApplicationController
        include ActionController::HttpAuthentication::Token::ControllerMethods

        skip_before_action :authenticate_user!, raise: false
        skip_before_action :verify_current_user_in_current_company!, raise: false
        
        before_action :require_company!
        before_action :initialize_service

        rescue_from CanCan::AccessDenied do |exception|
          render body: { message: 'Authentication failure' }, status: 401
        end

        def create
          authenticate_or_request_with_http_token do |api_token, options|
            result = @hire_bridge_service.create(api_token)
            render json: result, status: result[:status]
          end
        end

        private

        def hire_bridge_permitted_params
          params.permit(:_json)
        end
        
        def current_company
          @current_company ||= request.env['CURRENT_COMPANY']
        end

        def require_company!
          raise CanCan::AccessDenied unless current_company && current_company.active?
        end

        def initialize_service
          @hire_bridge_service = ::AtsIntegrationsService::HireBridge.new(@current_company, hire_bridge_permitted_params)
        end
      end
    end
  end
end