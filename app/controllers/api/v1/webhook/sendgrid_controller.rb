module Api
  module V1
    module Webhook
      class SendgridController < ApplicationController
        skip_before_action :authenticate_user!, raise: false
        skip_before_action :verify_current_user_in_current_company!, raise: false

        def events
          data = params["_json"]
          data = data[0] if data.kind_of?(Array)
          if data.present? && data["sg_message_id"]
            x_message_id = data["sg_message_id"].split(".").first
            email = UserEmail.find_by(message_id: x_message_id)
            if email.present?
              if data['event'] == 'delivered'
                email.activity["status"] = 'Delivered'
              elsif data['event'] == 'open'
                email.activity["status"] = 'Opened'
                email.activity["opens"] = email.activity["opens"].nil? ? 1 : email.activity["opens"] + 1
              elsif ['dropped', 'deferred', 'bounce', 'blocked'].include?(data['event'])
                email.activity['status'] = 'Not Delivered'
              end
              email.save
            elsif Rails.env.production?
              begin
                unless params.to_h.key?(:custome_event)
                  HTTParty.post('https://sapling.saplinghr.com/api/v1/sendgrid_events', body: params.to_h.merge!(custome_event: 'sapling-int'))
                else
                  HTTParty.post('https://webhook.kallidus-suite.com/hr/api/v1/sendgrid_events', body: params.to_h.merge!(custome_event: 'kallidus-live')) 
                end
              rescue Exception => e
              end
            end
          end
          create_logs(params, data)
          render body: Sapling::Application::EMPTY_BODY, status: 200
        end

        private 

        def create_logs(params, data)
          begin
            if data.present? && data['sg_message_id']
              return unless data['email']&.include?('zain.arshad')
              x_message_id = data['sg_message_id'].split('.').first
              error_message = 'Nothing'
            else
              data = params
              x_message_id = "NoMessageID"
              error_message = 'Data not found'
            end
            company = Company.find_by_subdomain('quality')
            LoggingService::WebhookLogging.new.create(company, 'SendGrid', x_message_id, data.to_json, '404', 'api/v1/webhook/sendgrid#events', error_message) if company
          rescue Exception => e
          end
        end
      end
    end
  end
end