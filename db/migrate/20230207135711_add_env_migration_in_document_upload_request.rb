class AddEnvMigrationInDocumentUploadRequest < ActiveRecord::Migration[6.0]
  def change
    add_column :document_upload_requests, :env_migration, :string, default: nil
  end
end
