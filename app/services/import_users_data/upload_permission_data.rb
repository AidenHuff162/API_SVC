# To assign user role/update permission via flatfile
module ImportUsersData
  class UploadPermissionData
    attr_reader :company, :current_user
    delegate :add_user_error_to_row, :send_feedback_email, to: :helper_service

    def initialize(**kwargs)
      @company = kwargs[:company]
      @data = kwargs[:data] || []
      @current_user = kwargs[:current_user]
      @upload_date = kwargs[:upload_date].to_date.strftime(company.get_date_format)
      @defected_entries = []
    end

    def perform
      header = @data[0].keys
      index = 0
      @data.try(:each) do |row|
        index += 1
        entry = row.to_hash
        begin
          update_user_role(entry)
        rescue StandardError => e
          @defected_entries.push(entry)
          add_user_error_to_row(row, "Row - #{index} - #{e.message}")
        end
      end
      send_feedback_email(build_attrs_for_feedback_email)
    end

    private

    def update_user_role(entry)
      user = company.users.where('id = ? OR email = ?',
                                  entry['User ID'].to_i, entry['Company Email'].try(:downcase)).take
      permission = entry['Permission']
      user_role = company.user_roles.find_by(id: entry['Permission'])
      validate_data(user, user_role)
      user.update!(user_role_id: permission)
      user.logout_user
    end

    def validate_data(user, user_role)
      raise 'User does not exist!' unless user
      raise 'User is not allowed to update its own permission!' unless user.id != current_user.id
      raise 'User role does not exist!' unless user_role

      ''
    end

    def build_attrs_for_feedback_email
      {
        data: @data, company: company, headers: @data[0].keys, upload_date: @upload_date, email: current_user.email,
        section_name: 'permissions', invalid_entries: @defected_entries, first_name: current_user.first_name
      }
    end

    def helper_service
      ImportUsersData::Helper.new
    end
  end
end
