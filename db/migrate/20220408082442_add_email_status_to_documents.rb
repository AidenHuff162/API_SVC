class AddEmailStatusToDocuments < ActiveRecord::Migration[5.1]
  def change
    add_column :paperwork_requests, :email_status, :string
    add_column :user_document_connections, :email_status, :string
  end
end
