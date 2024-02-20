class SftpForm < BaseForm
  
  SINGULAR_RELATIONS = %i(public_key)

  presents :sftp
  attribute :name, String
  attribute :host_url, String
  attribute :authentication_key_type, String
  attribute :user_name, String
  attribute :password, String
  attribute :port, Integer
  attribute :folder_path, String
  attribute :updated_by_id, Integer
  attribute :company_id, Integer
  attribute :public_key, UploadedFileForm::SftpPublicKeyForm

  validates :name, :host_url, :user_name, :authentication_key_type, :port, :updated_by_id, :company_id, :folder_path, presence: true
end
