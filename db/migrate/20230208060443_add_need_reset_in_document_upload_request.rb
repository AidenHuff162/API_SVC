class AddNeedResetInDocumentUploadRequest < ActiveRecord::Migration[6.0]
  def change
    add_column :document_upload_requests, :need_reset, :boolean, default: nil
  end
end
