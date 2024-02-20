class DocumentConnectionRelation < ApplicationRecord
  acts_as_paranoid
  has_many :user_document_connections
  has_many :users, through: :user_document_connections
  has_many :incomplete_requests,  -> { where("(user_document_connections.state = 'request') AND (user_document_connections.due_date is NULL OR user_document_connections.due_date >= ?)", Company.current.time.to_date) }, class_name: 'UserDocumentConnection'
  has_many :incomplete_overdue_requests,  -> { where("(user_document_connections.state = 'request') AND user_document_connections.due_date < ?", Company.current.time.to_date) }, class_name: 'UserDocumentConnection'
  has_one :document_upload_request
end
