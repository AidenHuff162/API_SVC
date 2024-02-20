class AddDocumentTokenToPaperworkRequestAndUserDocumentConnection < ActiveRecord::Migration[5.1]
  def change
    add_column :paperwork_requests, :document_token, :string
    add_column :user_document_connections, :document_token, :string
  end
end
