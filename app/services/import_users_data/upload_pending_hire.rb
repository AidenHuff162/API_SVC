module ImportUsersData
  class UploadPendingHire
    attr_reader :company, :import_method, :data, :current_user

    delegate :add_user_error_to_row, :send_feedback_email, to: :helper_service

    def initialize(**kwargs)
      @company = kwargs[:company]
      @data =  kwargs[:data] || []
      @current_user = kwargs[:current_user]
      @import_method = kwargs[:import_method]
      @defected_users = []
      @upload_date = kwargs[:upload_date].to_date.strftime(company.get_date_format)
      @date_regex = company.get_date_regex
    end

    def perform
      manage_pending_hires_user
    end

    private

    def transform_params(entry)
      entry = entry.delete_if { |_k, v| v.blank? }
      params = {}
      entry.each do |key, value|
        case key
        when 'Employment Status'
          params[:employee_type] = value
        when 'Location'
          params[:location_id] = company.locations.where(name: value).first_or_create&.id
        when 'Department'
          params[:team_id] = company.teams.where(name: value).first_or_create&.id
        when 'Status'
          params[:state] = value
        when 'Job Title'
          params[:title] = value
        when 'Start Date'
          params[:start_date] = Date.strptime(value, @date_regex)
        else
          index = key.to_s.parameterize.underscore.to_sym
          params[index] = value
        end
      end
      params
    end

    def manage_pending_hires_user
      index = 0
      header = data[0].keys
      data.try(:each) do |row|
        next if row['Personal Email'].blank?

        entry = row.dup
        entry = transform_params(entry)
        index += 1
        case import_method
        when 'Pending hires'
          handle_existing_pending_hires(entry, { row: row, index: index })
        when 'Create Pending hires'
          handle_new_pending_hires(entry, { row: row, index: index })
        end
      rescue StandardError => e
        @defected_users.push(row)
        add_user_error_to_row(row, "Row - 0 - #{e.message}")
      end
      send_feedback_email(build_attrs_for_feedback_email)
    end

    def handle_new_pending_hires(entry, **kwargs)
      company.pending_hires.create!(entry)
    rescue StandardError => e
      @defected_users.push(entry)
      add_user_error_to_row(kwargs[:row], "Row - #{kwargs[:index]} - #{e.message.split(',')[0]}")
    end

    def handle_existing_pending_hires(entry, **kwargs)
      index = kwargs[:index]
      row = kwargs[:row]
      pending_hire = company.pending_hires.find_by(personal_email: entry[:personal_email])
      if pending_hire.present?
        pending_hire.update!(entry)
        update_pending_hire_user(entry, pending_hire)
      else
        @defected_users.push(row)
        add_user_error_to_row(row, "Row - #{index} - Pending hire user does not exist")
      end
    rescue StandardError => e
      @defected_users.push(row)
      add_user_error_to_row(row, "Row - #{index} - #{e.message.split(',')[0]}")
    end

    def update_pending_hire_user(entry, pending_hire)
      user = pending_hire.company.users.where('email = ? OR personal_email = ? ', entry[:personal_email], entry[:personal_email]).take
      return if user.blank?

      employee_type = entry.delete(:employee_type)
      user.set_employee_type_field_option(CustomFieldOption.find_by(option: employee_type)&.id) if employee_type.present?
      user.update!(entry)
    end

    def section_mapper
      { 'Create Pending hires' => 'new_profile',
        'Pending hires' => 'existing_profile' } [import_method]
    end

    def build_attrs_for_feedback_email
      {
        data: data, company: company, headers: data[0].keys, upload_date: @upload_date, email: current_user.email,
        section_name: section_mapper, invalid_entries: @defected_users, first_name: current_user.first_name
      }
    end

    def helper_service
      ImportUsersData::Helper.new
    end
  end
end
