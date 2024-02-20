module Api
  module V1
    module Admin
      module WebhookIntegrations
        class FountainController < WebhookController

          def create
            ::AtsIntegrationsService::Fountain::ManageFountainWebhookVerification.new(params, request.headers['X-FOUNTAIN-PARTNER-SIGNATURE']).verify_and_create
          end

        end
      end
    end
  end
end
