module Api
  module V1
    module Webhook
      class JazzController < ApplicationController

        skip_before_action :authenticate_user!, raise: false
        skip_before_action :verify_current_user_in_current_company!, raise: false
        
        before_action :validate_request_headers
        before_action :initialize_service

        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 401
        end

        def create
          status = 202

          if request.headers['HTTP_X_JAZZHR_EVENT'] == 'CANDIDATE-EXPORT'
            @jazz_hr_service.manage_pending_hire
            status = 201
          
          elsif request.headers['HTTP_X_JAZZHR_EVENT'] == 'VERIFY'
            create_webhook_logging(@jazz_hr_service.fetch_company(), 'JazzHR', 'Verification Event', { agent: request.headers['HTTP_USER_AGENT'], 
              event: request.headers['HTTP_X_JAZZHR_EVENT'], data: params.to_json }, 'succeed', 'JazzController/create')
            
            status = 200
          end

          render body: Sapling::Application::EMPTY_BODY, status: status
        end

        private

        def validate_request_headers
          if request.headers['HTTP_USER_AGENT'] != 'JazzHR' && ['CANDIDATE-EXPORT', 'VERIFY'].exclude?(request.headers['HTTP_X_JAZZHR_EVENT'])
            #:nocov:
            create_webhook_logging(@jazz_hr_service.fetch_company(), 'JazzHR', 'Authentication Event', { agent: request.headers['HTTP_USER_AGENT'], 
              event: request.headers['HTTP_X_JAZZHR_EVENT'], data: params.to_json }, 'failed', 'JazzController/validate_request_headers')
            raise CanCan::AccessDenied
            #:nocov:
          end
        end

        def initialize_service
          @jazz_hr_service = AtsIntegrationsService::JazzHr.new(request, params.to_h)
        end
      end
    end
  end
end