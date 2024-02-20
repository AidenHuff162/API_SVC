class Sftp < ApplicationRecord
  acts_as_paranoid
  has_paper_trail

  belongs_to :updater, class_name: 'User', foreign_key: 'updated_by_id'

  belongs_to :company
  has_many :reports, dependent: :destroy
  delegate :full_name, to: :updater, prefix: :updater, allow_nil: true
  before_save :remove_public_key, if: Proc.new { |u| u.credentials? }
  before_save :remove_password, if: Proc.new { |u| u.public_key? }
  attr_encrypted :password, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']

  enum authentication_key_type: { credentials: 0, public_key: 1 }

  with_options as: :entity do |record|
    record.has_one :public_key, class_name: 'UploadedFile::SftpPublicKey'
  end

  def upload_public_key public_key 
    UploadedFile.create({
      entity_type: 'Sftp',
      file: public_key.file,
      type: 'UploadedFile::SftpPublicKey',
      company_id: public_key.company_id,
      original_filename: public_key.original_filename
    })
  end

  private

  def remove_public_key
    self.public_key&.destroy!
  end

  def remove_password
    self.password = nil
  end
end
