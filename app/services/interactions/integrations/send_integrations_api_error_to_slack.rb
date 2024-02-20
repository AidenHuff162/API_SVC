module Interactions
  module Integrations
    class SendIntegrationsApiErrorToSlack
      def perform
        IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.perform_later
      end
    end
  end
end
