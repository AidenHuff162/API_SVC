class AddUploadedToBambooToDocuments < ActiveRecord::Migration[5.1]
  def change
    add_column :paperwork_requests, :uploaded_to_bamboo, :boolean, default: false
    add_column :user_document_connections, :uploaded_to_bamboo, :boolean, default: false
  end
end
