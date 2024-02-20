module CompanySerializer
  class ProfileSetupPage < ActiveModel::Serializer
    attributes :id, :name, :prefrences, :tables_with_approval_flag, :team_digest_email, :ats_integration_types, :display_name_format, :date_format, :approval_feature_flag, :enable_custom_table_approval_engine, :profile_approval_feature_flag,
               :ohsa_covid_feature_flag, :lever_mapping_feature_flag, :smart_assignment_2_feature_flag, :smart_assignment_configuration, :national_id_field_feature_flag

    def prefrences
      prefrences = object.prefrences
      prefrences['default_fields'] = object.exclude_preferences(['wp']) unless object.working_patterns_feature_flag && object.enabled_time_off
      prefrences["default_fields"].each do |df|
        df["used_in_templates"] = object.profile_templates.joins(:profile_template_custom_field_connections).where(profile_template_custom_field_connections: {default_field_id: df["id"]}).pluck(:name)
      end
      prefrences
    end

    def tables_with_approval_flag
      if scope[:tables_with_approval].present?
        scope[:tables_with_approval]
      else
        false
      end
    end

    def smart_assignment_configuration
      ActiveModelSerializers::SerializableResource.new(object.smart_assignment_configuration, serializer: SmartAssignmentConfigurationSerializer::Basic) if object&.smart_assignment_configuration
    end
  end
end
