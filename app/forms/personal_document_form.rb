class PersonalDocumentForm < BaseForm
  presents :personal_documents

  SINGULAR_RELATIONS = %i(attached_file)

  attribute :user_id, Integer
  attribute :created_by_id, Integer
  attribute :title, String
  attribute :description, String
  attribute :attached_file, UploadedFileForm::PersonalDocumentFileForm
end
