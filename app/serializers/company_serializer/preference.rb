module CompanySerializer
  class Preference < ActiveModel::Serializer
    attributes :id, :name, :prefrences, :enabled_calendar, :enabled_time_off, :custom_tables_count, :default_country, :default_currency,
     :is_using_custom_table, :display_name_format, :date_format, :enable_custom_table_approval_engine, :show_performance_tab, :pto_paywall_feature_flag,
     :track_approve_paywall_feature_flag, :company_plan, :ui_switcher_feature_flag, :working_patterns_feature_flag

	  def prefrences
	  	if object.try(:is_using_custom_table).present?
        object.prefrences['default_fields'] = object.prefrences['default_fields'].select{ |preference_field|  !['td', 'tt', 'ltw', 'efr'].include?(preference_field['id'])  }
	  	end
      object.prefrences['default_fields'] = object.exclude_preferences(['wp']) unless object.working_patterns_feature_flag && object.enabled_time_off
      object.prefrences
	  end

	  def custom_tables_count
      object.get_cached_custom_tables_count
    end
  end
end
