module CompanySerializer
  class UserProfile < ActiveModel::Serializer
    attributes :id, :prefrences, :email_address, :name, :enabled_calendar, :enabled_time_off, :singular_department, :buddy, :preboarding_note, :preboarding_title, :custom_tables_count, :time_zone_abbreviation, :time_zone_offset, :default_country, :default_currency,
               :pto_events, :is_using_custom_table, :asana_integration_enabled, :team_digest_email, :display_name_format, :show_performance_tab, :intercom_feature_flag, :pto_paywall_feature_flag, :profile_fields_paywall_feature_flag, 
               :enable_custom_table_approval_engine, :track_approve_paywall_feature_flag, :company_plan, :zendesk_admin_feature_flag, :profile_approval_feature_flag, :integration_type, :adp_zip_validations_feature_flag,
               :adp_us_company_code_enabled, :adp_can_company_code_enabled, :adp_v2_migration_feature_flag, :national_id_field_feature_flag

    def singular_department
      object.department.singularize
    end

    def custom_tables_count
      object.get_cached_custom_tables_count
    end

    def time_zone_abbreviation
      ActiveSupport::TimeZone.find_tzinfo(object.time_zone).current_period.abbreviation
    end

    def time_zone_offset
      time = Time.now
      (time.in_time_zone(object.time_zone).utc_offset.to_f/1.hour.to_f) * -1
    end

    def pto_events
      object.pto_events
    end

    def prefrences
      object.prefrences['default_fields'] = object.exclude_preferences(['wp']) unless object.working_patterns_feature_flag && object.enabled_time_off
      object.prefrences
    end
  end
end
