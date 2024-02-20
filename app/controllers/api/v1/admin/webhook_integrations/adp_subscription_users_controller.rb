module Api
  module V1
    module Admin
      module WebhookIntegrations
        class AdpSubscriptionUsersController < WebhookController
          require 'oauth'
          require 'logger'
          require 'adp/connection'

          before_action :authenticate_subscription_webhook
          before_action :initialize_access_token

          def assign_users
            event_url = params[:url]
            response = @access_token.get(event_url)
            data = Hash.from_xml(response.body)
            
            AdpSubscriptionUser.assign_user(data, params[:env])
            render json: true
          end

          def unassign_users
            event_url = params[:url]
            response = @access_token.get(event_url)
            data = Hash.from_xml(response.body)

            AdpSubscriptionUser.unassign_user(data, params[:env])
            render json: true
          end

          private

          def authenticate_subscription_webhook
            verifier = ActiveSupport::MessageVerifier.new ENV['ADP_SUBSCRIPTION_SECRET_TOKEN']
            signature_token = ENV['ADP_SUBSCRIPTION_SIGNATURE_TOKEN']

            begin
              verified_signature_token = verifier.verify(params['signature_token'].split('saplingsapling')[0])

              raise 'exception' if signature_token != verified_signature_token
            rescue Exception => e
              head 401
            end
          end

          def initialize_access_token
            consumer_key = params[:env].downcase == 'us' ? ENV['ADP_US_OAUTH_CONSUMER_KEY'] : ENV['ADP_CAN_OAUTH_CONSUMER_KEY']
            consumer_secret = params[:env].downcase == 'us' ? ENV['ADP_US_OAUTH_CONSUMER_SECRET'] : ENV['ADP_CAN_OAUTH_CONSUMER_SECRET']

            consumer = OAuth::Consumer.new(consumer_key, consumer_secret)
            @access_token = OAuth::AccessToken.new(consumer)
          end
        end
      end
    end
  end
end
