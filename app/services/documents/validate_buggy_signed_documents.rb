module Documents
  class ValidateBuggySignedDocuments
    attr_reader :paperwork_request, :company, :request_response, :signer_doc_status, :cosigner_doc_status

    def initialize(paperwork_request)
      @paperwork_request = paperwork_request
      @company = @paperwork_request.user&.company
    end

    def perform
      return unless paperwork_request && company
      fix_paperwork_request()
    end

    private

    def fix_paperwork_request
      @request_response = get_hellosign_signature_request()
      return unless request_response.present?

      @signer_doc_status = request_response.signatures.map{ |m| m.data['status_code'] if (m.data['order'] == 0 || m.data['signer_role'] == 'employee' || m.data['signer_email_address'] == (paperwork_request.user.email || paperwork_request.user.personal_email)) }.compact&.first
      @cosigner_doc_status = request_response.signatures.map{ |m| m.data['status_code'] if (m.data['order'] == 1 || ['coworker', 'representative'].include?(m.data['signer_role']) || m.data['signer_email_address'] == (paperwork_request.co_signer.email || paperwork_request.co_signer.personal_email)) }.compact&.first if paperwork_request.co_signer_id

      if paperwork_request.assigned?
        manage_assigned_document()
      elsif paperwork_request.emp_submitted?
        manage_emp_submitted_document()
      elsif paperwork_request.signed? && is_cosigner_present?
        manage_signed_document()
      elsif paperwork_request.cosigner_submitted? && is_cosigner_present?
        manage_cosigner_submitted_document()
      end
    end

    def get_hellosign_signature_request
      HelloSign.get_signature_request(signature_request_id: paperwork_request.hellosign_signature_request_id)
    end

    def enqueue_firebase_event_call
      if HellosignCall.get_enqueued_calls_count(paperwork_request.id, 'firebase_signed_document').zero?
        HellosignCall.upload_signed_document_to_firebase(paperwork_request.id, paperwork_request.user.company_id, paperwork_request.user_id)
      end
    end

    def send_flip_document_email
      company.users.joins(:user_role).where(user_roles: { role_type: UserRole.role_types[:super_admin] }).try(:each) do |user|
        UserMailer.signatory_document_flipped_email(user).deliver_now
      end
    end

    def manage_assigned_document
      if signer_doc_status.eql?('signed')
        paperwork_request.emp_submit
        manage_emp_submitted_document()
      end
    end

    def manage_emp_submitted_document
      if signer_doc_status.eql?('signed')
        is_cosigner_present?() ? paperwork_request.sign : enqueue_firebase_event_call()
      elsif signer_doc_status.eql?('awaiting_signature')
        paperwork_request.assign
        send_flip_document_email()
      end
    end

    def manage_signed_document
      if cosigner_doc_status.eql?('signed')
        paperwork_request.cosigner_submit
        manage_cosigner_submitted_document()
      end
    end

    def manage_cosigner_submitted_document
      if cosigner_doc_status.eql?('signed')
        enqueue_firebase_event_call()
      elsif cosigner_doc_status.eql?('awaiting_signature')
        paperwork_request.skip_callback = true
        paperwork_request.sign
        send_flip_document_email()
      end
    end
    def is_cosigner_present?
      paperwork_request.co_signer_id.present?
    end
  end
end
