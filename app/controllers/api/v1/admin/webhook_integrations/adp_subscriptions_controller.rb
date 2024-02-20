module Api
  module V1
    module Admin
      module WebhookIntegrations
        require 'oauth'
        require 'logger'
        require 'adp/connection'

        class AdpSubscriptionsController < WebhookController
          before_action :current_company
          before_action :authenticate_subscription_webhook
          before_action :initialize_access_token

          def create_subscription
            event_url = params[:url]
            data = fetch_data(event_url)
            AdpSubscription.create_subscription(data, params[:env]) if data.present?

            render json: true
          end

          def change_subscription
            event_url = params[:url]
            data = fetch_data(event_url)
            AdpSubscription.change_subscription(data, params[:env]) if data.present?

            render json: true
          end

          def cancel_subscription
            event_url = params[:url]
            data = fetch_data(event_url)

            AdpSubscription.cancel_subscription(data, params[:env]) if data.present?
            render json: true
          end

          def notify_subscription
            event_url = params[:url]
            data = fetch_data(event_url)


            render json: true
          end

          def add_on
            event_url = params[:url]
            data = fetch_data(event_url)

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

          def fetch_data event_url
            data = nil
           
            if event_url.present?
              begin
                response = @access_token.get(event_url)
                data = Hash.from_xml(response.body)                
              rescue Exception => e
                create_integration_logging(current_company, 'ADP Marketplace', 'AdpSubscription - Failure', nil, {error: e.message, params: params}, 500) if current_company.present?
              end
            end
            
            data
          end
        end
      end
    end
  end
end

