class UserDocumentConnectionForm < BaseForm
  presents :user_document_connection

  PLURAL_RELATIONS = %i(attached_files)

  attribute :user_id, Integer
  attribute :document_upload_request_id, Integer
  attribute :state, String
  attribute :company_id, Integer
  attribute :attached_files, Array[UploadedFileForm::DocumentUploadRequestFileForm]
end
