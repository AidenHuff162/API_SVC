module PaperworkRequestSerializer
  class Full < ActiveModel::Serializer
    attributes :id, :hellosign_signature_id, :hellosign_signature_request_id, :hellosign_claim_url,
      :hellosign_signature_url, :is_signed, :user_id, :signed_document_url, :paperwork_packet_id,
      :template_ids, :sign_date, :unsigned_document_url, :is_assigned, :is_all_signed, :paperwork_packet_deleted,
      :description, :co_signer_id, :paperwork_packet_type, :send_completion_email, :company_id, :co_signer_type, :state
    has_one :document, serializer: DocumentSerializer::Full
    has_one :paperwork_packet, serializer: PaperworkPacketSerializer::Full
    has_one :paperwork_packet_deleted, serializer: PaperworkPacketSerializer::Full
    has_one :user, serializer: UserSerializer::Basic

    def is_signed
      object.state == "signed"
    end

    def is_assigned
      object.state == "assigned"
    end

    def is_all_signed
      object.state == "all_signed"
    end

    def description
      object.document.try(:description) if object.id
    end

    def signed_document_url
      if ( is_signed || ( object.co_signer_id && is_all_signed )) && object.signed_document
        object.get_signed_document_url
      end
    end

    def unsigned_document_url
      if is_assigned || (object.co_signer_id && is_signed )
        object.get_unsigned_document_url
      end
    end

    def company_id
      current_user.company_id
    end
  end
end
