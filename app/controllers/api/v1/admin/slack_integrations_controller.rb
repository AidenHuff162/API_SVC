module Api
  module V1
    module Admin
      class SlackIntegrationsController < ApiController
        before_action :validate_request, only: [:get_slack_command_data, :slack_respond, :slack_uninstall]

        def slack_auth
          ids = JsonWebToken.decode(params[:state])
          company = Company.find_by(id: ids["company_id"].to_i) rescue nil
          if company.present?
            SlackIntegrationJob.perform_async("Slack_Auth",{payload: params_permit.to_h,state: ids})
            redirect_to "https://#{company.app_domain}/#/admin/settings/integrations"
          end
        end

        def slack_respond
          integration_logging = LoggingService::IntegrationLogging.new.create(Company.find(459), 'Slack', 'slack_respond', {}, params.to_h, '200') rescue nil
          SlackIntegrationJob.perform_async("Slack_Respond",{payload: params.to_h})
        end

        def slack_help
          SlackIntegrationJob.perform_async("Slack_Help",{payload: params.to_h})
        end

        def get_slack_command_data
          #Use single route for all the commands just pass the command params from each command
          #sapling_team, sapling_out
          if ['out', 'team', 'time', 'tasks', 'request'].include? params[:text]
            SlackIntegrationJob.perform_async(params[:text],{payload: params.to_h}) if params[:command].present?
          else
            SlackIntegrationJob.perform_async("Slack_Help",{payload: params.to_h})
          end
        end

        def slack_uninstall
          if params["event"] && params_permit["team_id"]
            if ['app_uninstalled', 'tokens_revoked'].include?(params["event"]["type"])
              Integration.find_by(slack_team_id: params_permit["team_id"]).destroy! rescue nil
            elsif params["event"]["type"] == 'app_home_opened' && params["event"]["tab"] == 'messages'
              SlackIntegrationJob.perform_async("post_help_message",{payload: params.to_h})
            end
          end
          render status: 200, json: { challenge: params[:challenge] }
        end

        private
        def params_permit
          params.permit(:code,:payload,:response_url,:challenge,:team_id)
        end

        def validate_request
          Slack::Events::Request.new(request, {signing_secret: ENV['SLACK_SIGNING_SECRET'], signature_expires_in: 300}).verify!
        end
      end
    end
  end
end
