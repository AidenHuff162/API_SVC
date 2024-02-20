module Api
  module V1
    module Admin
      class JiraIntegrationsController < ApiController
        require 'resolv-replace'

        before_action :require_company!
        before_action :require_integration!
        before_action :authenticate_user!, except: [:issue_updated, :authorize]
        before_action :verify_current_user_in_current_company!, except: [:issue_updated, :authorize]
        before_action except: [:issue_updated, :authorize] do
          raise CanCan::AccessDenied unless (current_user.account_owner? || current_user.can_manage_integrations?)
        end
        
        before_action :get_jira_client, except: :generate_keys

        def issue_updated
          Logging.create!(company_id: current_company.id, action: "Jira issue updated webhook event", api_request: "None", integration_name: "jira", result: {params: params.inspect}, state: 200) if current_company.subdomain == 'rocketship' || current_company.subdomain == 'attentive'
          begin
            if params["webhookEvent"] == "jira:issue_updated" && params["issue"]["fields"]["status"]["name"] == @integration.jira_complete_status
              tuc = TaskUserConnection.find_by(jira_issue_id: params["issue"]["id"]) if params["issue"]["id"]
              if tuc && tuc.task_id.present? && tuc.in_progress?
                tuc.completed_by_method = TaskUserConnection.completed_by_methods[:jira]
                tuc.mark_task_completed
                history_description = I18n.t('history_notifications.task.completed', name: tuc.task[:name], assignee_name: tuc.user.try(:full_name))
                History.create_history({
                                     company: current_company,
                                     user_id: tuc.user_id,
                                     description: history_description,
                                     attached_users: [tuc.owner_id],
                                 })

                create_webhook_logging(current_company, 'Jira', 'Issue Updated', params.to_json, 'succeed', 'JiraIntegrationsController/issue_updated')
              end
            end
            
            @integration.update_column(:last_sync, DateTime.now)
            ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_webhook_statistics(current_company)
            return render json: 'JIRA Api Event Received', status: 200
          rescue Exception => error
            create_webhook_logging(current_company, 'Jira', 'Issue Updated', params.to_json, 'failed', 'JiraIntegrationsController/issue_updated', error.message)

            message = "The #{current_company.name} has failed to update issue for JIRA. We received #{params.to_json}"
            ::IntegrationErrors::SendIntegrationErrorNotificationToSlackJob.perform_now(message,
                  IntegrationErrorSlackWebhook.integration_types.key(IntegrationErrorSlackWebhook.integration_types[:issue_and_project_tracker])) if message.present?

            return render json: 'JIRA Api Event Failed', status: 200
          end
        end

        def generate_keys
          system "openssl genrsa -out private_key.pem 1024"
          system "openssl rsa -in private_key.pem -pubout -out public_key.pub"

          pdf = WickedPdf.new.pdf_from_string(File.read "public_key.pub")
          File.open("public_key.pdf", 'wb') do |file|
            file << pdf
          end

          private_key_file = File.open "private_key.pem"
          public_key_file = File.open "public_key.pdf"

          @integration.client_id = SecureRandom.urlsafe_base64(nil, false)
          @integration.private_key_file = private_key_file
          @integration.public_key_file = public_key_file
          @integration.save!

          respond_with @integration, serializer: IntegrationSerializer::Full
        end

        def initialize_integration
          begin
          if Rails.env.production? || Rails.env.staging?
            callback_url = "https://" + current_company.domain + "/api/v1/admin/jira_integrations/authorize/"
          else
            callback_url = "http://" + current_company.domain + "/api/v1/admin/jira_integrations/authorize/"
          end
          request_token = @jira_client.request_token(oauth_callback: callback_url)

          respond_with json: {url: request_token.authorize_url}, status: 200
          rescue Exception => e
            if e.message.include? '502'
              return render json: {errors: I18n.t('errors.jira_busy').to_s}, status: 3000
            else
              return render json: {errors: I18n.t('notifications.admin.integration.error.check_setting', name: "JIRA").to_s}, status: 3000
            end
          end
        end

        def authorize
          begin
            if params[:oauth_verifier]
              request_token = @jira_client.set_request_token(
                params[:oauth_token], @integration.client_id
              )
              access_token = @jira_client.init_access_token(oauth_verifier: params[:oauth_verifier])

              @integration.jira_issue_statuses = get_jira_statuses
              @integration.secret_token = access_token.token
              @integration.client_secret = access_token.secret
              @integration.save!
              register_webhooks
            end
          rescue Exception => exception
            LoggingService::IntegrationLogging.new.create(current_company, 'JIRA', 'Authorization-ERROR', params.to_h, {error: exception.message}, 401) if current_company.present?
          end
          if Rails.env.production? || Rails.env.staging?
            redirect_to "https://" + current_company.app_domain + "/#/admin/settings/integrations"
          else
            redirect_to "http://" + current_company.app_domain + "/#/admin/settings/integrations"
          end
         end

        def destroy
          if @integration.destroy
            render json: {status: 200}
          else
            render json: {status: 500}
          end
        end

        private

        def require_integration!
          @integration = Integration.where(company_id: current_company.id, api_name: 'jira').first
        end

        def get_jira_client
          if @integration
            private_key_file_path = nil
            if !Rails.env.development? && !Rails.env.test?
              private_key_file = Tempfile.new(['private_key_file', '.pem'])
              private_key_file.binmode
              retries ||= 0
              begin
                private_key_file.write open(@integration.private_key_file.url).read
              rescue Net::OpenTimeout, Net::ReadTimeout
                retry if (retries += 1) < 3
              end
              private_key_file.rewind
              private_key_file.close
              private_key_file_path = private_key_file.path
            else
              private_key_file_path = "public#{@integration.private_key_file.url}"
            end

            options = {
              private_key_file: private_key_file_path,
              consumer_key: @integration.client_id,
              context_path: '',
              site: @integration.channel
            }

            @jira_client = JIRA::Client.new(options)

            if @integration.client_secret && @integration.secret_token
              @jira_client.set_access_token(
                @integration.secret_token,
                @integration.client_secret
              )
            end
          end
        end

        def register_webhooks
          webhook = @jira_client.Webhook.build
          hook_url = ""
          if Rails.env.production? || Rails.env.staging?
            hook_url = "https://#{current_company.domain}/api/v1/admin/jira_integrations/issue_updated"
          else
            hook_url = "http://#{current_company.domain}/api/v1/admin/jira_integrations/issue_updated"
          end
          company_code = @integration.company_code
          webhook.save({
            "name" => "Sapling webhook for issue updates",
            "url" => hook_url,
            "events" => [
              "jira:issue_updated"
            ],
            "filters" => {
              "issue-related-events-section" => "project = '#{company_code}' AND summary ~ \"\\\\[Sapling\\\\]\""
            },
            "excludeIssueDetails" => "false"
          })
        end

        def get_jira_statuses
          issuetypes = @jira_client.get("#{@jira_client.options[:rest_base_path]}/project/#{@integration.company_code}/statuses").body
          issuetypes = JSON.parse issuetypes
          issue_statuses = []
          issuetypes.each do |issue|
            statuses = []
            issue["statuses"].each do |status|
              statuses.push status["name"]
            end
            issue_statuses.push({ name: issue['name'], statuses: statuses}.to_json)
          end
          issue_statuses
        end
      end
    end
  end
end
