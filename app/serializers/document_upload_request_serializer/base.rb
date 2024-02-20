module DocumentUploadRequestSerializer
  class Base < ActiveModel::Serializer
    type :document_upload_request

    attributes :id, :title, :description, :global, :special_user_id, :company_id, :created_at, :position, :document_connection_relation_id, :meta, :locations, :departments, :status

    belongs_to :document_connection_relation, serializer: DocumentConnectionRelationSerializer::Dashboard
    belongs_to :special_user, class_name: 'User', serializer: UserSerializer::Profile
    belongs_to :user, serializer: UserSerializer::Profile

    def title
      object.get_title
    end

    def description
      object.get_description
    end

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
