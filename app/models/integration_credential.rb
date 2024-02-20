class IntegrationCredential < ApplicationRecord
  belongs_to :integration_instance
  belongs_to :integration_configuration
  has_one :api_key, dependent: :destroy

  attr_encrypted :value, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']

  scope :by_name, -> (name) { where("trim(name) ILIKE ?", name) }
  
  after_save :reset_cache, if: Proc.new { |ic| ic.saved_changes.keys.include?('value') }
  after_create :create_api_key, if: Proc.new { |ic| ic.integration_configuration && ic.integration_configuration.field_type == 'sapling_api_key' }

  def reset_cache
  	Rails.cache.delete("#{integration_instance_id}/integration_instance_#{name.downcase.strip}")
  end

  def create_api_key
    ApiKey.create(company_id: self.integration_instance.company_id, key: self.value, name: 'Recruit Kallidus', integration_credential_id: self.id, api_key_type: ApiKey.api_key_types[:recruit], auto_renew: true)
  end
end
