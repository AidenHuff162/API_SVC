module CompanySerializer
  class UserPilotInformation < ActiveModel::Serializer
    attributes :id, :name, :created_at, :locations_count, :people_count, :users_count, :teams_count, :api_names,
               :enabled_calendar, :enabled_org_chart, :enabled_time_off,:include_activities_in_email, :include_documents_preboarding,
               :is_using_custom_table, :links_enabled, :manager_emails, :manager_form_emails, :new_coworker_emails,
               :new_manager_form_emails, :new_pending_hire_emails, :new_tasks_emails, :notifications_enabled,
               :offboarding_activity_notification, :onboarding_activity_notification, :outstanding_tasks_emails,
               :preboarding_complete_emails, :send_notification_before_start, :start_date_change_emails,
               :team_digest_email, :transition_activity_notification, :enable_gsuite_integration, :document_completion_emails,
               :scheduled_emails, :workflows_count, :profile_template_count

    def api_names
      object.integrations.pluck(:api_name)
    end

    def scheduled_emails
      UserEmail.where('Date(invite_at) > ?', Date.today).joins(user: :company).where("users.company_id = ?", object.id).count
    end

    def workflows_count
      object.workstreams.count
    end

    def profile_template_count
      object.profile_templates.count
    end
  end
end
