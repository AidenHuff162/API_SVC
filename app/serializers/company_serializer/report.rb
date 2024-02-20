module CompanySerializer
  class Report < ActiveModel::Serializer
    attributes :id, :name, :logo, :authentication_type, :enabled_calendar,
               :date_format, :enabled_time_off, :prefrences, :account_type,
               :is_using_custom_table, :company_pto_policies_ids, :surveys_enabled,
               :limited_sandbox_access, :company_plan, :company_trial_feature_flag,
               :smart_assignment_2_feature_flag, :smart_assignment_configuration,
               :integration_type, :ui_switcher_feature_flag

    has_one :billing, serializer: BillingSerializer


    def prefrences
      prefrences = object.prefrences
      prefrences['default_fields'] = object.exclude_preferences(['wp']) unless object.working_patterns_feature_flag && object.enabled_time_off
      prefrences
    end

    def company_pto_policies_ids
    	object.pto_policies.ids if object.pto_policies.present?
    end

    def smart_assignment_configuration
      ActiveModelSerializers::SerializableResource.new(object.smart_assignment_configuration, serializer: SmartAssignmentConfigurationSerializer::Basic) if object&.smart_assignment_configuration
    end
  end
end
