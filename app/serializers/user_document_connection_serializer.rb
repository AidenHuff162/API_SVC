module UserDocumentConnectionSerializer
  class Full < ActiveModel::Serializer
    attributes :id,:document_connection_relation_id, :user_id, :created_at, :state, :description, :global
    belongs_to :document_connection_relation
    has_many :attached_files, each_serializer: AttachmentSerializer
    belongs_to :paperwork_packet, serializer: PaperworkPacketSerializer::Description

    def global
      DocumentUploadRequest.with_deleted.find_by(document_connection_relation_id: object.document_connection_relation_id).try(:global) if object.document_connection_relation_id
    end

    def description
      object.document_connection_relation.description if object.present? && object.document_connection_relation.present?
    end
  end
end
