class IntegrationConfiguration < ApplicationRecord
  belongs_to :integration_inventory
  has_many :integration_credentials, dependent: :destroy

  validates_uniqueness_of :field_name, scope: [:integration_inventory_id], conditions: -> { where(category: 'credentials') }
  validates_uniqueness_of :toggle_context, scope: [:integration_inventory_id], conditions: -> { where(category: 'settings') }
  validates_uniqueness_of :toggle_identifier, scope: [:integration_inventory_id], conditions: -> { where(category: 'settings') }

  after_save :update_integration_credentials, if: Proc.new { |ic| ic.saved_change_to_field_name? &&  ic.category == 'credentials'}
  after_save :update_integration_settings, if: Proc.new { |ic| ic.saved_change_to_toggle_identifier? &&  ic.category == 'settings'}
  
  after_create :create_integration_instance_default_credentials, if: Proc.new { |ic| ic.category == 'credentials'}  
  after_create :create_integration_instance_default_settings, if: Proc.new { |ic| ic.category == 'settings'}  

  enum category: { credentials: 0, settings: 1 }
  
  private
  
  def update_integration_credentials
    self.integration_credentials.update_all(name: self.field_name)
    reset_cache(self.field_name, self.field_name_before_last_save)
  end

  def update_integration_settings
    self.integration_credentials.update_all(name: self.toggle_identifier)
    reset_cache(self.toggle_identifier, self.toggle_identifier_before_last_save)
  end

  def create_integration_instance_default_credentials
    instances = IntegrationInstance.where(integration_inventory_id: self.integration_inventory_id)
    instances.find_each do |instance|
      instance.integration_credentials.create(name: self.field_name, integration_configuration_id: self.id)
    end
  end

  def create_integration_instance_default_settings
    instances = IntegrationInstance.where(integration_inventory_id: integration_inventory_id)
    instances.find_each do |instance|
      instance.integration_credentials.create(name: toggle_identifier, integration_configuration_id: id, value: 'false')
    end
  end

  def reset_cache(configuration_name, configuration_name_before_last_save)
    instances = IntegrationInstance.where(integration_inventory_id: self.integration_inventory_id)
    instances.find_each do |instance|
      Rails.cache.delete("#{instance.id}/integration_instance_#{configuration_name&.downcase&.strip}")
      Rails.cache.delete("#{instance.id}/integration_instance_#{configuration_name_before_last_save&.downcase&.strip}")
    end
  end
end

