module CompanySerializer
  class CompanyEmailsSetting < ActiveModel::Serializer
    attributes :id, :name, :include_activities_in_email, :overdue_notification,
               :sender_name, :send_notification_before_start, 
               :onboarding_activity_notification, :transition_activity_notification, 
               :offboarding_activity_notification, :document_completion_emails, :new_pending_hire_emails,
               :preboarding_complete_emails, :start_date_change_emails, :team_digest_email, :buddy_emails,
               :new_manager_form_emails, :manager_form_emails, :manager_emails, :email_rebranding_feature_flag
  end
end
