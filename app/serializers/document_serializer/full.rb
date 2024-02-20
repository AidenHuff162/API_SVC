module DocumentSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :title, :description, :attached_file, :meta, :locations, :departments, :status
    has_one :attached_file

    def locations
      if object.meta["location_id"] == ['all']
        ['all']
      else
        Company.find(object.company_id).locations.where(id: object.meta["location_id"])
      end
    end

    def departments
      if object.meta["team_id"] == ['all']
        ['all']
      else
        Company.find(object.company_id).teams.where(id: object.meta["team_id"])
      end
    end

    def status
      if object.meta["employee_type"] == ['all']
        ['all']
      else
        Company.find(object.company_id).custom_fields.find_by(field_type: CustomField.field_types[:employment_status]).custom_field_options.where(option: object.meta["employee_type"])
      end
    end

  end
end
