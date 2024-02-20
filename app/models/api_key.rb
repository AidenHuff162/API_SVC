class ApiKey < ApplicationRecord
  require 'scrypt'

  has_paper_trail

  belongs_to :company
  belongs_to :edited_by, class_name: 'User'
  belongs_to :integration_credentials

  attr_encrypted_options.merge!(:encode => true)
  attr_encrypted :key, key: ENV['ENCRYPTION_API_KEY'], algorithm: ENV['ENCRYPTION_API_ALGORITHM']

  validates :name, :encrypted_key, :encrypted_key_iv, presence: true
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  
  before_create :create_scrypted_key
  before_create :update_last_hit

  enum api_key_type: { general: 0, recruit: 1 }

  def create_scrypted_key
    self.key = SCrypt::Password.create(self.key)
  end
  
  def update_last_hit
    self.last_hit = Time.current
  end

  def is_token_valid?
    expires_in() > 0 
  end

  def expires_in
    90 - (((Time.now - last_hit) / 86400).to_i)
  end

  def renew_api_key
    update_last_hit()
    self.save!
  end
end
