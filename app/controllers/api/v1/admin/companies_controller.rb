module Api
  module V1
    module Admin
      class CompaniesController < BaseController

        before_action only: [:current, :company_with_team_and_locations, :revoke_token, :show_webhook_token] do
          if params[:offboarding_view]
            ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab], "offboard_teams_locations")
          else
            ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
          end
        end
        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204 if params[:sub_tab].present?
        end

        def index
          collection = CompaniesCollection.new(params)
          respond_with collection.results, each_serializer: CompanySerializer::Short
        end

        def company_with_team_and_locations
          data = current_company.teams_and_locations
          render json: data.to_json
        end

        def with_managers
          if params[:directory_managers]
            data = current_company.directory_managers
          elsif params[:active_managers]
            data = current_company.active_managers
          else
            data = current_company.managers
          end
          respond_with User.where(id: data), each_serializer: UserSerializer::ManagerFilter
        end

        def update_shareableurl
          unless current_user.account_owner?
            render json: { errors: [Errors::Unauthorized.error] }, status: :unauthorized
          end
          if params[:regenerate_url]
            current_company.generate_token
          else
            current_company.update_column(:token, nil)
          end
          respond_with current_company, serializer: CompanySerializer::Basic, scope: { shareable_org_chart: true }, include: '**'
        end

        def default_profile_setup
          respond_with current_company, serializer: CompanySerializer::Preference
        end

        def profile_setup_page
          Rails.configuration.ld_client ||= LaunchDarkly::LDClient.new(ENV['LAUNCH_DARKLY_KEY'])
          ld_user_context = current_company.create_ld_user_context(current_company.name, false)
          updates_page = Rails.application.config.ld_client.variation('updates-page', ld_user_context, false)
          respond_with current_company, serializer: CompanySerializer::ProfileSetupPage, scope: {updates_page: updates_page}
        end

        def current
          authorize! :read, current_company.reload
          company_filter
        end

        def update
          authorize! :update, current_company.reload
          company = CompanyForm.new(params.merge(id: current_company.id, error_notification_emails: current_company.error_notification_emails))
          company.save!
          if params[:company_email_settings_serializer].present?
            respond_with current_company.reload, serializer: CompanySerializer::CompanyEmailsSetting, include: '**'
          else
            respond_with current_company.reload, serializer: CompanySerializer::Full, include: '**'
          end

          slack_message =  nil
          history_description = nil
          if current_company.new_tasks_emails != params[:new_tasks_emails]
            PushEventJob.perform_later('settings-updated', current_user, {
              company_name: current_company[:name],
              updated: "New Tasks Emails",
              operation: params.to_h[:new_tasks_emails]? "Enabled" : "Disabled"
            })
            slack_message = I18n.t('slack_notifications.company.setting_updated', name: current_company[:name])
            history_description = I18n.t('history_notifications.company.setting_updated', field: 'New Tasks Emails')
          elsif current_company.outstanding_tasks_emails != params[:outstanding_tasks_emails]
            PushEventJob.perform_later('settings-updated', current_user, {
              company_name: current_company[:name],
              updated: "Outstanding Tasks Emails",
              operation: params.to_h[:outstanding_tasks_emails]? "Enabled" : "Disabled"
            })
            slack_message = I18n.t('slack_notifications.company.setting_updated', name: current_company[:name])
            history_description = I18n.t('history_notifications.company.setting_updated', field: 'Outstanding Task Emails')
          elsif current_company.new_coworker_emails != params[:new_coworker_emails]
            PushEventJob.perform_later('settings-updated', current_user, {
              company_name: current_company[:name],
              updated: "New Coworker Emails",
              operation: params.to_h[:new_coworker_emails]? "Enabled" : "Disabled"
            })
            slack_message = I18n.t('slack_notifications.company.setting_updated', name: current_company[:name])
            history_description = I18n.t('history_notifications.company.setting_updated', field: 'New Coworker Emails')
          elsif current_company.preboarding_complete_emails != params[:preboarding_complete_emails]
            PushEventJob.perform_later('settings-updated', current_user, {
              company_name: current_company[:name],
              updated: "Preboarding Complete Emails",
              operation: params.to_h[:preboarding_complete_emails]? "Enabled" : "Disabled"
            })
            slack_message = I18n.t('slack_notifications.company.setting_updated', name: current_company[:name])
            history_description = I18n.t('history_notifications.company.setting_updated', field: 'Preboarding Complete Emails')
          elsif current_company.buddy_emails != params[:buddy_emails]
            PushEventJob.perform_later('settings-updated', current_user, {
              company_name: current_company[:name],
              updated: "Buddy Emails",
              operation: params.to_h[:buddy_emails]? "Enabled" : "Disabled"
            })
            slack_message = I18n.t('slack_notifications.company.setting_updated', name: current_company[:name])
            history_description = I18n.t('history_notifications.company.setting_updated', field: 'Buddy Emails')
          elsif current_company.manager_emails != params[:manager_emails]
            PushEventJob.perform_later('settings-updated', current_user, {
              company_name: current_company[:name],
              updated: "Manager Emails",
              operation: params.to_h[:manager_emails]? "Enabled" : "Disabled"
            })
            slack_message = I18n.t('slack_notifications.company.setting_updated', name: current_company[:name])
            history_description = I18n.t('history_notifications.company.setting_updated', field: 'Manager Emails')
          elsif current_company.new_pending_hire_emails != params[:new_pending_hire_emails]
            PushEventJob.perform_later('settings-updated', current_user, {
              company_name: current_company[:name],
              updated: "New Pending Hire Emails",
              operation: params.to_h[:new_pending_hire_emails]? "Enabled" : "Disabled"
            })
            slack_message = I18n.t('slack_notifications.company.setting_updated', name: current_company[:name])
            history_description = I18n.t('history_notifications.company.setting_updated', field: 'New Pending Hire Emails')
          else
            value_count = CompanyValue.count
            milestone_count = Milestone.count
            image_count = UploadedFile.where(type: 'UploadedFile::GalleryImage').count
            PushEventJob.perform_later('general-info-updated', current_user, {
              company_name: current_company[:name],
              company_email: current_company[:email],
              gallery_image_count: image_count,
              milestone_count: milestone_count,
              company_value_count: value_count
            })
            slack_message = I18n.t('slack_notifications.company.information_updated', name: current_company[:name])
            history_description = I18n.t('history_notifications.company.information_updated', name: current_company[:name])
          end

          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: slack_message
          }) if slack_message.present?
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description
          }) if history_description.present?

          Interactions::HistoryLog::CompanyHistoryLog.log(current_company,params,current_user.id)
        end

        def visualization_data
          params[:date_filter] = params[:date_filter].present? ? Date.parse(params[:date_filter]) : Date.today
          data = current_company.get_visualization_data(params)
          render json: data.to_json
        end

        def turnover_data
          params[:date_filter] = params[:date_filter].present? ? Date.parse(params[:date_filter]) : Date.today
          data = current_company.get_turnover_data(params)
          render json: data.to_json
        end

        def revoke_token
          current_company.revoke_token 
          respond_with current_company, serializer: CompanySerializer::WebhookPage, token_visible: true
        end

        def show_webhook_token
          respond_with current_company, serializer: CompanySerializer::WebhookPage, token_visible: params[:token_visible] == "show"
        end

        private

        def company_filter
          if params[:dashboard_company_serializer].present?
            respond_with current_company, serializer: CompanySerializer::Dashboard, include: '**'
          elsif params[:email_company_serializer].present?
            respond_with current_company, serializer: CompanySerializer::CompanyEmail, include: '**'
          elsif params[:company_employee_record_serializer].present?
            respond_with current_company, serializer: CompanySerializer::EmployeeRecord, include: '**'
          elsif params[:onboarding_user_company_serializer].present?
            respond_with current_company, serializer: CompanySerializer::OnboardingUser, include: '**'
          elsif params[:company_role_serializer].present?
            respond_with current_company, serializer: CompanySerializer::CompanyRole, include: '**'
          elsif params[:company_general_serializer].present?
            respond_with current_company, serializer: CompanySerializer::General, include: '**'
          elsif params[:company_email_settings_serializer].present?
            respond_with current_company, serializer: CompanySerializer::CompanyEmailsSetting, include: '**'
          elsif params[:company_group_serializer].present?
            respond_with current_company, serializer: CompanySerializer::CompanyGroup, include: '**'
          elsif params[:company_overview_report_serializer].present?
            respond_with current_company, serializer: CompanySerializer::OverviewReport, include: '**'
          elsif params[:company_report_serializer].present?
            respond_with current_company, serializer: CompanySerializer::Report, include: '**'
          elsif params[:timeoff_report_serializer].present?
            respond_with current_company, serializer: CompanySerializer::TimeoffReport, include: '**'
          elsif params[:profile_report_serializer].present?
            respond_with current_company, serializer: CompanySerializer::ProfileReport, include: '**'
          elsif params[:survey_report_serializer].present?
            respond_with current_company, serializer: CompanySerializer::SurveyReport, include: '**'
          elsif params[:show_inbox].present?
            respond_with current_company, serializer: CompanySerializer::Basic, include: '**', scope: {inbox_page: true}
           elsif params[:pending_hire_page].present?
            respond_with current_company, serializer: CompanySerializer::PendingHire, include: '**'
          else
            respond_with current_company, serializer: CompanySerializer::Basic, include: '**'
          end
        end

      end
    end
  end
end
