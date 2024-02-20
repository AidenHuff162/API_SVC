module PendingHireSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :personal_email, :email, :phone_number, :title, :location_id,
               :team_id, :start_date, :employee_type, :base_salary, :hourly_rate, :bonus, :address_line_1,
               :address_line_2, :city, :address_state, :zip_code, :level, :custom_role, :flsa_code, :manager_id,
               :custom_fields, :name, :team_name, :location_name, :manager_name, :user_id, :lever_custom_fields,
               :provision_gsuite, :send_credentials_type, :send_credentials_time, :send_credentials_offset_before,
               :send_credentials_timezone, :is_basic_format_custom_data, :preferred_name, :workday_id, :workday_id_type,
               :workday_custom_fields, :workday_worker_subtype, :hashed_phone_number, :duplication_type,
               :data_changed, :country, :working_pattern_id

    has_one :location, serializer: LocationSerializer::Short
    has_one :team, serializer: TeamSerializer::Short
    has_one :manager, serializer: UserSerializer::Short
    has_one :user, serializer: UserSerializer::People

    def name
      object.company.global_display_name(object, object.company.display_name_format)
    end

    def team_name
      object.team.name if object.team
    end

    def email
      object.user.email if object.user
    end

    def location_name
      object.location.name if object.location
    end

    def manager_name
      object.manager.full_name if object.manager
    end

    def employee_type
      object.employee_type
    end

    def hashed_phone_number
      object.hashed_phone_number
    end

    def data_changed
      if scope[:duplication] && object.duplication_type == 'info_change'
        object.changed_info
      end
    end

    def start_date
      begin
        object.start_date.present? ? Time.parse(object.start_date).to_date.to_s : ""
      rescue
        object.start_date.present? ? object.start_date : ""
      end
    end

  end
end
