module Api
  module V1
    module Admin
      class IntegrationsController < BaseController
        include ADPHandler

        before_action :set_integration, only: [:update]
        load_and_authorize_resource except: [:index, :check_slack_integration, :sync_adp_us_users, :sync_adp_can_users, :fetch_adp_onboarding_templates, :fetch_lever_requisition_fields, :generate_jazz_credentials, :generate_breezy_credentials, :enable_linked_in_integration]
        authorize_resource only: [:sync_adp_us_users, :sync_adp_can_users, :fetch_adp_onboarding_templates, :fetch_adp_onboarding_templates, :fetch_lever_requisition_fields, :generate_jazz_credentials, :generate_breezy_credentials, :enable_linked_in_integration]

        before_action only: [:index] do
          ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
        end
        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204 if params[:sub_tab].present?
        end

        def index
          respond_with current_company.integrations, each_serializer: IntegrationSerializer::Full
        end

        def create
          integration = current_company.integrations.create!(integration_params)
          respond_with integration, serializer: IntegrationSerializer::Full
        end

        def update
          @integration.update!(integration_params)
          respond_with @integration, serializer: IntegrationSerializer::Full
        end

        def set_integration
          @integration = current_company.integrations.find(params[:id])
        end

        def check_slack_integration
          slack_integration = current_company.integrations.find_by(api_name: "slack_notification")
          if slack_integration
            respond_with slack_integration, serializer: IntegrationSerializer::Basic
          else
            render body: Sapling::Application::EMPTY_BODY, status: 204
          end
        end

        def sync_adp_can_users
          ReceiveUpdatedEmployeeFromAdpWorkforceNowJob.perform_later(current_company.id, 'adp_wfn_can')
          render :json => {status: 200}
        end

        def sync_adp_us_users
          ReceiveUpdatedEmployeeFromAdpWorkforceNowJob.perform_later(current_company.id, 'adp_wfn_us')
          render :json => {status: 200}
        end

        def fetch_adp_onboarding_templates
          respond_with fetch_onboarding_templates.to_json
        end

        def fetch_lever_requisition_fields
          fields, status = LeverService::FetchRequisitionFields.new(current_company).perform
          render :json => {lever_fields: fields, status: status}
        end

        def generate_jazz_credentials
          render json: {client_id: Integration.generate_scrypt_client_id(current_company), client_secret: Integration.generate_scrypt_client_secret(current_company)}, status: 200
        end

        def destroy
          if @integration.destroy
            if @integration.api_name == "slack_notification"
              SlackIntegrationJob.perform_async("Disable_Users_Slack_Notification",{current_company_id: current_company.id})
            end
            render :json => {status: 200}
          else
            render :json => {status: 500}
          end
        end

        def enable_linked_in_integration
          AtsIntegrationsService::LinkedIn.new(current_company, params, true).update_extension
          render body: Sapling::Application::EMPTY_BODY, status: 200
        end

        def generate_ats_credentials
          render json: { client_id: Integration.generate_api_token(current_company, params['api_name']) }, status: 200
        end

        private

        def integration_params
          if params[:api_name].present? && params[:api_name] == 'xero'
            params.permit(:id, :api_name, :employee_group_name, :organization_name, :payroll_calendar_id, :earnings_rate_id)
          else
            params.permit(:id, :api_name, :api_key, :secret_token, :is_enabled, :webhook_url,
              :channel, :subdomain, :signature_token, :enable_create_profile, :client_id, :api_company_id,
              :client_secret, :company_code, :jira_issue_type, :jira_complete_status, :identity_provider_sso_url, :saml_certificate,
              :saml_metadata_endpoint, :subscription_id, :access_token, :gsuite_account_url ,:gsuite_admin_email,
              :can_import_data, :region, :enable_update_profile, :asana_organization_id, :asana_default_team,
              :asana_personal_token, :iusername, :ipassword, :workday_human_resource_wsdl, :link_gsuite_personal_email, :can_export_updation,
              :enable_onboarding_templates, :hiring_context, :employee_group_name, :organization_name, :payroll_calendar_id, :earnings_rate_id,
              :can_invite_profile, :can_delete_profile, :enable_company_code, :enable_international_templates, :enable_tax_type, :sync_preferred_name).merge(meta: params[:meta])
          end
        end

        def collection_params
          params.merge(company_id: current_company.id)
        end

      end
    end
  end
end
