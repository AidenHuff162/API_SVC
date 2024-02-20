module DocumentConnectionRelationSerializer
  class Dashboard < ActiveModel::Serializer
    attributes :id, :title, :description, :doc_owners_count, :user_document_connections

    def doc_owners_count
      object.user_document_connections.where(state: 'request').where.not(user_id: nil).pluck(:user_id).uniq.count
    end

    def user_document_connections
      # object.user_document_connections
      object.user_document_connections.where.not(user_id: nil).map{|udc| {id:udc.id, company_id: udc.company_id, created_by_id: udc.created_by_id, deleted_at: udc.deleted_at, state: udc.state, document_connection_relation_id: udc.document_connection_relation_id, packet_id: udc.packet_id, user_id: udc.user_id, user_picture: udc.user&.picture, user_display_name: udc.user&.display_name}}
    end
  end
end
