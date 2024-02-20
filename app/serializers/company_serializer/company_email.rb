module CompanySerializer
  class CompanyEmail < ActiveModel::Serializer
    attributes :id, :start_date_change_emails, :onboarding_activity_notification, :transition_activity_notification,
               :offboarding_activity_notification, :include_activities_in_email, :outstanding_tasks_emails, :new_tasks_emails,
               :new_coworker_emails, :preboarding_complete_emails, :buddy_emails, :manager_emails, :new_pending_hire_emails,
               :new_manager_form_emails, :document_completion_emails, :start_date_change_emails, :manager_form_emails, :buddy,
               :custom_fields, :singular_department, :enabled_time_off, :team_digest_email, :from_email_list,
               :display_name_format, :time_zone, :include_documents_preboarding, :email_rebranding_feature_flag, 
               :company_plan, :smart_assignment_2_feature_flag, :smart_assignment_configuration, :ui_switcher_feature_flag

    def custom_fields
      ActiveModelSerializers::SerializableResource.new(object.custom_fields, each_serializer: CustomFieldSerializer::Basic)
    end

    def singular_department
      object.department.singularize
    end

    def from_email_list
      default_email = "#{current_user.company.sender_name} (#{current_user.company.subdomain}@#{ENV['DEFAULT_HOST']})"
      if current_user.email.present?
        ["#{current_user.full_name} (#{current_user.email})", default_email]
      else
        [default_email]
      end
    end

    def smart_assignment_configuration
      ActiveModelSerializers::SerializableResource.new(object.smart_assignment_configuration, serializer: SmartAssignmentConfigurationSerializer::Basic) if object&.smart_assignment_configuration
    end
  end
end
