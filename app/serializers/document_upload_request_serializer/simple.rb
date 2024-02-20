module DocumentUploadRequestSerializer
  class Simple < ActiveModel::Serializer
    attributes :id, :title, :global, :position
    belongs_to :document_connection_relation

    def title
      object.get_title
    end
  end
end
