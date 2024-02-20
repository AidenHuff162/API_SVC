class DocumentUploadRequestForm < BaseForm
  SINGULAR_RELATIONS = %i(document_connection_relation)

  attribute :company_id, Integer
  attribute :special_user_id, Integer
  attribute :global, Boolean
  attribute :position, Integer
  attribute :user_id, Integer
  attribute :meta, JSON
  attribute :document_connection_relation, DocumentConnectionRelationForm
  attribute :updated_by_id, Integer

  validates :company_id, presence: true
  validates :global, inclusion: { in: [true, false] }

  def get_title
    self.document_connection_relation.present? ? self.document_connection_relation.title : ""
  end

  def get_description
    self.document_connection_relation.present? ? self.document_connection_relation.description : ""
  end
end
