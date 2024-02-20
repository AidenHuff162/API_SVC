module IndividualDocumentsSerializer
  class Dashboard < ActiveModel::Serializer
    type :paperwork_template

    attributes :title, :description, :type, :representative, :is_manager_representative, :team_members, :process_type

    def read_attribute_for_serialization(attr)
      if object.key? attr.to_s
        attr.to_s == 'meta' ? JSON.parse(object['meta']) : object[attr.to_s]
      else
        self.send(attr) rescue nil
      end
    end

    def representative
      user_rep = scope[:company].users.find_by(id: object['representative_id']) if object['type'] == 0 && object['representative_id'].present?
      user_rep.present? ? ActiveModelSerializers::SerializableResource.new(user_rep, serializer: UserSerializer::DashboardPendingDocumentRepresentative) : nil
    end

    def is_manager_representative
      object['is_manager_representative'].present? ? object['is_manager_representative'] : false
    end

    def team_members
      if object['type'] == 1
        if scope[:process_type] == 'Overdue Documents'
          ActiveModelSerializers::SerializableResource.new(DocumentConnectionRelation.find(object['id']).incomplete_overdue_requests.exclude_offboarded_user_documents(scope[:company].id).includes(:user) , each_serializer: PaperworkRequestSerializer::Dashboard)
        else
          ActiveModelSerializers::SerializableResource.new(DocumentConnectionRelation.find(object['id']).incomplete_requests.exclude_offboarded_user_documents(scope[:company].id).includes(:user) , each_serializer: PaperworkRequestSerializer::Dashboard)
        end
      else
        if scope[:process_type] == 'Overdue Documents'
          ActiveModelSerializers::SerializableResource.new(Document.find(object['id']).incomplete_overdue_paperwork_requests.exclude_offboarded_user_documents.includes(:user) , each_serializer: PaperworkRequestSerializer::Dashboard)
        else
          ActiveModelSerializers::SerializableResource.new(Document.find(object['id']).incomplete_paperwork_requests.exclude_offboarded_user_documents.includes(:user) , each_serializer: PaperworkRequestSerializer::Dashboard)
        end
      end
    end

    def process_type
      scope[:process_type] == 'Overdue Documents' ? 'overdue document' : 'open document'
    end
    
  end
end
