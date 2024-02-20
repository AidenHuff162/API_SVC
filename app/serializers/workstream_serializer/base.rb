module WorkstreamSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :name, :tasks_count, :position, :send_to_asana, :updated_at, :updated_by, :meta,:locations,
               :departments, :status, :process_type, :user_assigned_count, :sort_type

    def send_to_asana
      current_user.company.asana_integration_enabled
    end

    def updated_at
      object.company.convert_time(object.updated_at, true) rescue ''
    end

    def locations
      if object.meta && object.meta["location_id"] == ['all']
        ['all']
      elsif object.meta
        Company.find(object.company_id).locations.where(id: object.meta["location_id"])
      end
    end

    def departments
      if object.meta && object.meta["team_id"] == ['all']
        ['all']
      elsif object.meta
        Company.find(object.company_id).teams.where(id: object.meta["team_id"])
      end
    end

    def status
      if object.meta && object.meta["employee_type"] == ['all']
        ['all']
      elsif object.meta
        Company.find(object.company_id).custom_fields.find_by(field_type: CustomField.field_types[:employment_status])&.custom_field_options&.where(id: object.meta["employee_type"])
      end
    end

    def updated_by
      if object.updated_by.present?
        object.updated_by.display_name
      else
        "Admin"
      end
    end

    def process_type
      object.process_type if object.process_type
    end

    def user_assigned_count
      TaskUserConnection.joins(:task).where(tasks: {workstream_id: object.id}).pluck(:user_id).uniq.count
    end
  end
end
