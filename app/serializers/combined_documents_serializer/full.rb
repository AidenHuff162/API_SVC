module CombinedDocumentsSerializer
  class Full < ActiveModel::Serializer
    type :paperwork_request

  	attributes :id, :title, :created_by, :created_at, :state, :user_id, :co_signer_id, :signed_document,
               :unsigned_document, :creator_id, :description, :hellosign_signature_request_id, :co_signer_name,
               :packet_name, :document_type, :attached_files, :user_preferred_full_name, :due_date

    def created_at
     object.created_at.in_time_zone(object.company.time_zone)
    end

    def attached_files
      attachments = []
      if object["document_type"] == "upload_request"
        attachments = UploadedFile.where(type: "UploadedFile::DocumentUploadRequestFile", entity_type: "UserDocumentConnection", entity_id: object["id"].to_i)
      elsif object["document_type"] == "paperwork_request"
        attachments = PaperworkRequest.find(object["id"].to_i).document.attached_file
        attachments = attachments.nil? ? [] : [attachments]
      end
      if attachments
        ActiveModelSerializers::SerializableResource.new(attachments, each_serializer: AttachmentSerializer)
      end
    end

    def read_attribute_for_serialization(attr)
      if object.key? attr.to_s
        object[attr.to_s]

      else
        self.send(attr) rescue nil
      end
    end

    def user_preferred_full_name
      User.find_by(id: object["user_id"]).try(:preferred_full_name)
    end

  end
end
