module CompanySerializer
  class UserInfo < ActiveModel::Serializer
    attributes :id, :prefrences, :name, :enabled_calendar, :enabled_time_off, :singular_department, :buddy, :time_zone_offset, :date_format,
     :time_zone_abbreviation, :custom_tables_count, :default_country, :default_currency, :is_using_custom_table, :team_digest_email,
     :show_performance_tab

    def singular_department
      object.department.singularize
    end

    def time_zone_offset
      time = Time.now
      time_zone_offset = (time.in_time_zone(object.time_zone).utc_offset.to_f/1.hour.to_f) * -1
    end

    def time_zone_abbreviation
      ActiveSupport::TimeZone.find_tzinfo(object.time_zone).current_period.abbreviation
    end

    def custom_tables_count
      object.get_cached_custom_tables_count
    end

  end
end
