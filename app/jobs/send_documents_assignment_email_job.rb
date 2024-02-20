class SendDocumentsAssignmentEmailJob
  include Sidekiq::Worker, SendDocumentAssignmentEmail
  sidekiq_options queue: :send_documents_assignment_email, retry: 0, backtrace: true

  def perform(document_id, document_type)
    return unless document_id.present? && document_type.present?
    
    if document_type == 'paperwork_request'
      document = PaperworkRequest.find_by_id(document_id)
    elsif document_type == 'user_document_connection'
      document = UserDocumentConnection.find_by_id(document_id)
    end
    send_document_assignment_email(document)
  end

end