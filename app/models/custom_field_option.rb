class CustomFieldOption < ApplicationRecord
  has_paper_trail
  default_scope { order(:position) }
  belongs_to :custom_field
  belongs_to :owner, class_name: 'User'
  has_many :custom_field_values, dependent: :destroy
  has_many :users, -> {  where.not(current_stage: [User.current_stages[:incomplete], User.current_stages[:departed]], state: 'inactive') }, through: :custom_field_values, source: :user
  has_many :unscoped_users, through: :custom_field_values, source: :user
  validate :name_uniqueness, on: [:update, :create]
  accepts_nested_attributes_for :custom_field_values, allow_destroy: true

  def name_uniqueness
    if CustomFieldOption.where(option: self.option, custom_field_id: self.custom_field_id).where.not(id: self.id, custom_field_id: nil).count > 0
      errors.add(:name, ' is already in use.')
    end
  end

  def self.get_custom_field_option(custom_field, option)
    return if !option.present?
    custom_field.custom_field_options.find_by('option ILIKE ?', option)
  end

  def self.create_custom_field_option(company, field_name, option)
    return unless option.present?
      
    custom_field = company.custom_fields.where('name ILIKE ?', field_name).take
    if custom_field.present? && custom_field.mcq?
      custom_field.custom_field_options.where('option ILIKE ?', option).first_or_create(option: option) 
    end
  end

  def self.sync_adp_option_and_code(company, field_name, option, code, environment, field_id = nil)
    return unless option.present? && code.present? && environment.present? && option.to_s != 'Terminated'

    option_field = nil
    custom_field = field_name.present? ? company.custom_fields.where('name ILIKE ?', field_name).take : company.custom_fields.find_by_id(field_id)
    
    if custom_field.present? && (custom_field.mcq? || custom_field.employment_status?) 
      key = environment == 'US' ? 'adp_wfn_us_code_value' : 'adp_wfn_can_code_value'
      option_field = custom_field.custom_field_options.where("option ILIKE ? OR #{key} = ?", option, code)&.take
      option_field = custom_field.custom_field_options.new unless option_field
      option_field.assign_attributes(option: option, "#{key}": code, active: true)
      option_field.save
    end
    return option_field&.id
  end

  def self.deactivate_adp_options(field_name, company, updated_option_ids, environment, field_id = nil)
    custom_field = field_name.present? ? company.custom_fields.where('name ILIKE ?', field_name).take : company.custom_fields.find_by_id(field_id)

    key = environment == 'US' ? 'adp_wfn_us_code_value' : 'adp_wfn_can_code_value'
    custom_field.custom_field_options.where.not('id IN (?)', updated_option_ids).where("#{key} IS NOT NULL").update_all(active: false)
  end
end
