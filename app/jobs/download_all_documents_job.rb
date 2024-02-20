class DownloadAllDocumentsJob < ApplicationJob
  def perform(user, url_key, user_document_connection_id, company_id=nil, admin_email=nil)
    Interactions::Users::DownloadAllDocuments.new(user, url_key, user_document_connection_id, company_id, admin_email).perform
  end
end
