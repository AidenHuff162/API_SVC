module WebhookEventServices
  class HelperService

    def fetch_webhooks(company, event_data)
      event_type = event_data[:type]
      case event_type
      when 'new_pending_hire'
        fetch_pending_hire_webhooks(company, event_type)
      when 'stage_completed', 'stage_started', 'onboarding', 'offboarding'
        fetch_stage_change_webhooks(company, event_type, event_data[:stage], event_data[:triggered_for])
      when 'key_date_reached'
        fetch_key_date_reached_webhooks(company, event_type, event_data[:date_types], event_data[:triggered_for])
      when 'profile_changed', 'job_details_changed'
        fetch_profile_changed_webhooks(company, event_type, event_data[:values_changed], event_data[:triggered_for])
      end
    end

    def fetch_users(company, current_date)
      users = company.users.not_inactive_incomplete.where(generate_query(current_date)).pluck(:id)
      company.users.not_inactive_incomplete.where(state: 'active').find_each { |u| users << u.id if check_birthday(get_birthday(u), current_date)} if birthday_event_exists?(company)
      return users.uniq
    end

    def check_birthday(birthday, current_date)
      birthday&.month == current_date.month && birthday&.day == current_date.day
    end

    def get_date_types(user_id, company)
      user = company.users.find_by(id: user_id)
      return {} if user.blank?

      types = []
      current_date = company.time.to_date

      Webhook::DATE_TYPES.map(&:parameterize).map(&:underscore).each do |key|
        case key
        when 'start_date', 'termination_date', 'last_day_worked'
          types << key if user.send(key) == current_date
        when 'birthday'
          types << key if check_birthday(get_birthday(user), current_date)
        when 'anniversary_date'
          types << key if check_anniversary(user.start_date, current_date)
        end
      end
      return {date_types: types}
    end

    def get_values_changed(company, sections, user_attributes, params, profile_update=false, table_name=nil, effective_date=nil)
      values_changed =[]
      date_format = company.get_date_format
      company.prefrences['default_fields'].map { |field| field['api_field_id'] if sections.include?(field['section'])}.compact.each do |key|
        next if Webhook::EXCLUDED_FIELDS.map(&:parameterize).map(&:underscore).include?(key)
        value_changed =  {}
        case key
        when 'status'
          value_changed = params.keys.exclude?('state') ? {} : get_hash(user_attributes, key, 'state', params)
        when 'start_date'
          value_changed =  params.keys.exclude?(key) ? {} : { field_id: key, values: { fieldName: key.titleize, oldValue: format_date(date_format, user_attributes[key]), newValue: format_date(date_format, params[key]) } } if params[key].present? && user_attributes[key].present? && params[key].try(:to_date).strftime('%Y-%m-%d') != user_attributes[key].try(:to_date).strftime('%Y-%m-%d')
        when 'manager', 'buddy'
          value_key = "#{key}_id"
          value_changed = params.keys.exclude?(value_key) ? {} : { field_id: key, values: { fieldName: key.titleize, oldValue: company.users.find_by_id(user_attributes[value_key]).try(:preferred_full_name), newValue: company.users.find_by_id(params[value_key]).try(:preferred_full_name) } } if params[value_key]&.to_s != user_attributes[value_key]&.to_s
        when 'location'
          value_key = "location_id"
          value_changed = params.keys.exclude?(value_key) ? {} : { field_id: key, values: { fieldName: key.titleize, oldValue: company.locations.find_by_id(user_attributes[value_key]).try(:name), newValue: company.locations.find_by_id(params[value_key]).try(:name) } } if params[value_key]&.to_s != user_attributes[value_key]&.to_s
        when 'department'
          value_key = "team_id"
          value_changed = params.keys.exclude?(value_key) ? {} : { field_id: key, values: { fieldName: key.titleize, oldValue: company.teams.find_by_id(user_attributes[value_key]).try(:name), newValue: company.teams.find_by_id(params[value_key]).try(:name) } } if params[value_key]&.to_s != user_attributes[value_key]&.to_s
        when 'company_email'
          value_changed = params.keys.exclude?('email') ? {} : get_hash(user_attributes, key, 'email', params)
        when 'job_title'
          value_changed = params.keys.exclude?('title') ? {} : get_hash(user_attributes, key, 'title', params)
        when 'about', 'linkedin', 'twitter', 'github', 'facebook'
          value_key = (key == 'about' && profile_update) ? 'about_you' : key
          value_changed = params.keys.exclude?(value_key) ? {} : get_hash(user_attributes, key, value_key, params)
        else
          value_changed = params.keys.exclude?(key) ? {} : get_hash(user_attributes, key, key, params)
        end

        if value_changed.empty?.blank?
          value_changed[:values] = {tableName: table_name}.merge(value_changed[:values]) if table_name.present?
          value_changed[:values].merge!({effectiveDate: format_date(date_format, effective_date)}) if effective_date.present?
          values_changed << value_changed
        end
      end
      values_changed
    end

    def format_date(date_format, date)
      date.to_date.strftime(date_format) rescue ''
    end

    private
    def fetch_stage_change_webhooks(company, event_type, stage, user_id)
      webhook_by_filters(company, user_id).where(state: :active, event: event_type.to_sym).where("configurable -> 'stages' ?| array[:stages]", stages: [stage, "all"])
    end

    def fetch_key_date_reached_webhooks(company, event_type, date_types, user_id)
      webhook_by_filters(company, user_id).where(state: :active, event: event_type.to_sym).where("configurable -> 'date_types' ?| array[:date_types] OR configurable -> 'date_types' ?| array['all']", date_types: date_types)
    end

    def fetch_profile_changed_webhooks(company, event_type, values_changed, user_id)
      webhook_by_filters(company, user_id).where(state: :active, event: event_type.to_sym).where.not(target_url: nil).where("configurable -> 'fields' ?| array[:fields]", fields: values_changed.map { |v| v['field_id'] })
    end

    def webhook_by_filters(company, user_id)
      company.webhooks.webhooks_by_filters(company, user_id)
    end

    def fetch_pending_hire_webhooks(company, event_type)
      company.webhooks.where(state: :active, event: event_type.to_sym)
    end

    def apply_to_location?(filters, user)
      location_ids = filters['location_id']
      location_ids.include?('all')  || (location_ids.present? && user.location_id.present? && location_ids.include?(user.location_id))
    end

    def apply_to_team?(filters, user)
      team_ids = filters['team_id']
      team_ids.include?('all') || (team_ids.present? && user.team_id.present? && team_ids.include?(user.team_id))
    end

    def apply_to_employee_type?(filters, user)
      employee_types = filters['employee_type']
      employee_types.include?('all') || (employee_types.present? && user.employee_type_field_option&.option.present? && employee_types.include?(user.employee_type_field_option&.option))
    end

    def generate_query(date)
      "(start_date = '#{date}' OR termination_date = '#{date}' OR last_day_worked = '#{date}' OR (start_date != '#{date}' AND EXTRACT(MONTH FROM start_date) =  #{date.month} AND EXTRACT(DAY FROM start_date) = #{date.day}))"
    end

    def birthday_event_exists?(company)
      configured_dates = company.webhooks.where(state: :active, event: Webhook.events[:key_date_reached]).pluck(:configurable).map {|c| c['date_types']}.flatten.uniq
      configured_dates.present? && (configured_dates & ['all', 'birthday']).any?
    end

    def check_anniversary(start_date, current_date)
      current_date != start_date && start_date.month == current_date.month && start_date.day == current_date.day
    end

    def get_hash(user_attributes, key, value_key, params)
      params[value_key] != user_attributes[value_key] ? { field_id: key, values: { fieldName: key.titleize, oldValue: user_attributes[value_key], newValue: params[value_key] } } : {}
    end

    def get_birthday(user); user.date_of_birth.try(:to_date) rescue nil end
  end
end
