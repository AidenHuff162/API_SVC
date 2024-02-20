module SendDocumentAssignmentEmail
  extend ActiveSupport::Concern

  def send_document_assignment_email(document)
    case document.class.name.try(:downcase)
    when 'paperworkrequest'
      send_signatory_document_email(document)
    when 'userdocumentconnection'
      send_upload_document_email(document)
    end
  end

  private

  def send_signatory_document_email(document)
    document_data_hash = case (document.co_signer_id? && document.email_completely_sent?)
                         when true
                          { id: document.user_id, document_type: 'paperwork_request', document_id: document.id, co_signer_id: document.co_signer_id }
                         when false
                          { id: document.user_id, document_type: 'paperwork_request', document_id: document.id }
                         end
    trigger_email(document_data_hash)
  end

  def send_upload_document_email(document)
    trigger_email({ id: document.user_id, document_type: 'document_upload_request', document_id: document.id })
  end

  def trigger_email(document_data_hash)
    return unless document_data_hash

    Interactions::Users::DocumentAssignedEmail.new(document_data_hash).perform
  end
end
