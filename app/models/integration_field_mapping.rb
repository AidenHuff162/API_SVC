class IntegrationFieldMapping < ActiveRecord::Base
  include IntegrationParamMapperOperations

  belongs_to :integration_instance
  belongs_to :custom_field
  belongs_to :company

  scope :fetch_mapping_against_key, -> (field_key, instance_id) { where(integration_instance_id: instance_id).where("integration_field_key ILIKE ?", field_key).take }
  scope :in_order, -> { order("integration_field_key") }
  
  def self.field_name_filter(value)
    custom_field_ids = CustomField.where("name ILIKE ?", "%#{value}%").pluck(:id)
    preference_field_ids = Company.first.prefrences['default_fields'].map {|field| field['id'] if field['name'].downcase.include?(value.downcase)}
    IntegrationFieldMapping.where('custom_field_id IN (?) OR preference_field_id IN (?)', custom_field_ids, preference_field_ids)
  end

  def self.ransackable_scopes(_auth_object = nil)
    %i(field_name_filter)
  end

  validates_presence_of :integration_field_key, :company_id, :field_position
  validate :field_id_is_present?
  validates :integration_field_key, uniqueness: {scope: [:integration_field_key, :custom_field_id , :integration_instance_id, :field_position], message: 'Integration Field Mapping Uniqueness Constraint Violated.'}

  def field_id_is_present?
    errors.add('', "Field ID should be present") if self.preference_field_id.nil? && self.custom_field_id.nil?
  end 

  def get_field_mapping_direction
    self&.integration_instance&.integration_inventory&.field_mapping_direction
  end
end
