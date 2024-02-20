class SendDueDocumentsEmailJob < ApplicationJob
  queue_as :send_due_documents_email

  def perform(requests, document_type, is_from_preview_panel, company)
    return unless requests.present? && document_type.present? && company.present?
    
    unless is_from_preview_panel
      case document_type
      when 0 # Paperwork request
        requests = PaperworkRequest.where(id: requests)
      when 1 # Upload Request
        requests = UserDocumentConnection.where(id: requests)
      end
    end
    requests.each do |request|
      if is_from_preview_panel
        user = company.users.find_by(id: request)
      else
        user = request.user
      end
      UserMailer.due_documents_email(user, company).deliver_now!
    end

  end

end