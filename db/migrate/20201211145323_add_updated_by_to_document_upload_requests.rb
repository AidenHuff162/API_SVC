class AddUpdatedByToDocumentUploadRequests < ActiveRecord::Migration[5.1]
  def change
    add_reference :document_upload_requests, :updated_by, index: true
  end
end
