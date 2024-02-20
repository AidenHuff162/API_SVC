module Api
  module V1
    module Admin
      module WebhookIntegrations
        class WorkableController < WebhookController

          before_action :workable_credentials, only: [:create, :subscribe, :unsubscribe]

          include JsonResponder
          respond_to :json
          responders :json

       		def workable_authorize
            render json: true
       		end

          def subscribe
            subscription = { id: nil }
            if @workable_api.present? && @workable_api.subdomain.present? && @workable_api.access_token.present?
              workable = AtsIntegrations::Workable.new(current_company, @workable_api)
              subscription[:id] = workable.subscribe()
            end
            respond_with subscription.to_json
          end

          def unsubscribe
            subscription = { id: @workable_api.subscription_id }
            if @workable_api.present? && @workable_api.subdomain.present? && @workable_api.access_token.present? && @workable_api.subscription_id.present?
              workable = AtsIntegrations::Workable.new(current_company, @workable_api)
              workable.unsubscribe()
              @workable_api.reload
              subscription = { id: @workable_api.subscription_id }
            end
            respond_with subscription.to_json
          end

          def create
            webhook_executed = 'failed'
            error = nil
            
            begin
              if request.env['HTTP_X_WORKABLE_SIGNATURE']
                workable = AtsIntegrations::Workable.new(current_company, @workable_api)
                workable.create(params)
                @workable_api.update_column(:synced_at, DateTime.now) if @workable_api
                webhook_executed = 'succeed'
                
                log_success_webhook_statistics(current_company)
              end
            rescue Exception => exception
              error = exception.message
              log_failed_webhook_statistics(current_company)

              webhook_executed = 'failed'
            ensure 
              create_webhook_logging(current_company, 'Workable', 'Create', {data: params.to_json, domain: request.domain}, webhook_executed, 'WorkableController/create', error)
            end

            render json: true
          end
        end
      end
    end
	end
end
