module ImportUsersData
  class UploadHolidayData
    attr_reader :company, :current_user, :invalid_holidays, :upload_date, :data, :lde_data, :date_regex, :entry
    delegate :add_user_error_to_row, :downcase_and_to_array, :send_feedback_email, to: :helper_service

    def initialize(**kwargs)
      @company, @current_user, @data = kwargs.values_at(:company, :current_user, :data)
      @data, @invalid_holidays, @date_regex = (data || []), [], company.get_date_regex
      @upload_date = kwargs[:upload_date].to_date.strftime(company.get_date_format)
      @lde_data = build_lde_filters_data.freeze
    end

    def perform
      data.each.with_index(1) do |row, index|
        @entry = row
        @entry = transform_params(entry.merge({'Multiple Dates' => false}))
        entry[:created_by_id] = current_user.id
        create_holidays({ row: row, index: index })
      end
      send_feedback_email(build_attrs_for_feedback_email)
    end

    private

    def transform_params(params)
      params.map{ |key, value| send("get_#{key.parameterize(separator: '_')}", value) }.to_h
    end

    def get_holiday_name(value)
      [:name, value]
    end

    def get_start_date(value)
      [:begin_date, value.present? ? Date.strptime(value, date_regex) : value]
    end

    def get_end_date(value)
      end_date = value.present? ? value : entry['Start Date']
      [:end_date, end_date.present? ? Date.strptime(end_date, date_regex) : end_date]
    end

    def get_employment_status(value)
      [:status_permission_level, value.downcase == 'all' ? [value.downcase] : downcase_and_to_array(value).map { |value| lde_data[:employment_status][value] }]
    end

    def get_locations(value)
      [:location_permission_level, value.downcase == 'all' ? [value.downcase] : downcase_and_to_array(value).map { |value| lde_data[:locations][value] }]
    end

    def get_departments(value)
      [:team_permission_level, value.downcase == 'all' ? [value.downcase] : downcase_and_to_array(value).map { |value| lde_data[:departments][value] }]
    end

    def get_multiple_dates(_)
      [:multiple_dates, entry['End Date'].present?]
    end

    def build_lde_filters_data
      {
        departments: company.teams.pluck('lower(name), id').to_h,
        locations: company.locations.pluck('lower(name), id').to_h,
        employment_status: company.employment_field.custom_field_options.pluck('lower(option), option').to_h
      }
    end

    def create_holidays(**kwargs)
      begin
        invalid_filters = get_invalid_lde_filters
        raise get_invalid_lde_error_message(invalid_filters) if invalid_filters.present?
        company.holidays.create!(entry)
      rescue StandardError => e
        invalid_holidays.push(entry.merge({holidays_error: e.message}))
        add_user_error_to_row(kwargs[:row], "Row - #{kwargs[:index]} - #{e.message}")
      end
    end

    def build_attrs_for_feedback_email
      {
        data: data, company: company, headers: data[0].keys, section_name: 'holidays', upload_date: upload_date,
        email: current_user.email, invalid_entries: invalid_holidays, first_name: current_user.first_name
      }
    end

    def get_invalid_lde_filters
      %i[status_permission_level location_permission_level team_permission_level].reject { |attr| entry[attr].all? }
    end

    def error_lde_mapper(lde_keys)
      {
        status_permission_level: 'Employment Status',
        location_permission_level: 'Location',
        team_permission_level: 'Departments'
      }.values_at(*lde_keys)
    end

    def get_invalid_lde_error_message(invalid_filters)
      "Holiday <b>#{entry[:name]}</b> was not uploaded as #{error_lde_mapper(invalid_filters).join(', ')} filters do not exist"
    end

    def helper_service
      ImportUsersData::Helper.new
    end
  end
end
