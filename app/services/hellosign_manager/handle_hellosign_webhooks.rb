module HellosignManager
  class HandleHellosignWebhooks
    attr_reader :paperwork_request, :event_type

    def initialize(hellosign_signature_request_id, event_type)
      @paperwork_request = PaperworkRequest.find_by(hellosign_signature_request_id: hellosign_signature_request_id)
      @event_type = event_type.try(:downcase)
    end

    def perform
      return unless paperwork_request
      handle_webhook
    end

    private

    def handle_webhook
      case event_type
      when PaperworkRequest::HELLOSIGN_REQUEST_DOWNLOADABLE_EVENT
        handle_signature_request_downloadable
      when PaperworkRequest::HELLOSIGN_REQUEST_SIGNED_EVENT
        handle_signature_request_signed
      when PaperworkRequest::HELLOSIGN_REQUEST_ALL_SIGNED_EVENT
        handle_signature_request_all_signed
      end
    end

    def handle_signature_request_downloadable
      return if (paperwork_request.cosigner_submitted? || paperwork_request.all_signed?)
      paperwork_request.download_half_signed_document
    end

    def handle_signature_request_signed
      paperwork_request.sign if paperwork_request.emp_submitted? && paperwork_request.co_signer_id
    end

    def handle_signature_request_all_signed
      if ( paperwork_request.co_signer_id.blank? && paperwork_request.emp_submitted? ) || ( paperwork_request.co_signer_id && paperwork_request.cosigner_submitted? )
        enqueue_firebase_event_call()
      end 
    end

    def enqueue_firebase_event_call
      HellosignCall.upload_signed_document_to_firebase(paperwork_request.id, paperwork_request.user.company_id, paperwork_request.user_id)
    end
  end
end
