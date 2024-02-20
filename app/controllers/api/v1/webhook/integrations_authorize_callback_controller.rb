module Api
  module V1
    module Webhook
      class IntegrationsAuthorizeCallbackController < ApplicationController

        def callback
          redirect_to IntegrationsService::DetectIntegrationBasedUrl.call(params)
        end
      end
    end
  end
end