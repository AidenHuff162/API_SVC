# frozen_string_literal: true

module ImportUsersData
  class UploadGroupData
    attr_reader :company, :current_user
    delegate :add_user_error_to_row, :send_feedback_email, to: :helper_service

    def initialize(**kwargs)
      @company = kwargs[:company]
      @data = kwargs[:data] || []
      @current_user = kwargs[:current_user]
      @defected_entries = []
      @upload_date = kwargs[:upload_date].to_date.strftime(company.get_date_format)
    end

    def perform
      header = @data[0].keys
      index = 0
      @data.try(:each) do |row|
        index += 1
        add_new_options(row, index)
      end
      send_feedback_email(build_attrs_for_feedback_email)
    end

    def add_new_options(row, index)
      entry = row.to_hash.transform_values! { |a| a&.strip rescue a }
      create_group_options(entry['Group Type'], entry['Group Name'])
    rescue StandardError => e
      @defected_entries.push(entry)
      add_user_error_to_row(row, "Row - #{index} - #{e.message}")
    end

    def create_group_options(group_type, group_name)
      case group_type
      when 'Location'
        company.locations.create!(name: group_name)
      when 'Department'
        company.teams.create!(name: group_name)
      else
        create_custom_group_options(group_type, group_name)
      end
    end

    def create_custom_group_options(group_type, group_name)
      custom_group = company.custom_fields.find_by(name: group_type)
      raise "#{group_type} does not exist!" unless custom_group

      custom_group.custom_field_options.create!(option: group_name)
    end

    def build_attrs_for_feedback_email
      {
        data: @data, company: company, headers: @data[0].keys, section_name: 'groups', upload_date: @upload_date, 
        email: current_user.email, invalid_entries: @defected_entries, first_name: current_user.first_name
      }
     end

    def helper_service
      ImportUsersData::Helper.new
    end
  end
end
