module InboxSerializer
  class EmailTemplateSerializer < Base
    attributes :email_type, :name, :editor, :permission_group_ids, :location_ids, :department_ids, 
               :status_ids, :locations, :departments, :status, :permission_type, :individuals, :meta

    def editor
      object.get_editor
    end

    def individuals
      ActiveModelSerializers::SerializableResource.new(object.company.users.where(id: object.permission_group_ids), each_serializer: UserSerializer::CustomAlertNotifier) if object.permission_type == 'individual'
    end

    def email_type
      object.map_email_type
    end

    def locations 
      object.get_locations
    end
  end
end
