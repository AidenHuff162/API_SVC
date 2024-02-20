class FieldHistory < ApplicationRecord
  has_paper_trail
  belongs_to :field_changer, class_name: 'User'
  belongs_to :field_auditable, polymorphic: true
  belongs_to :custom_field
  belongs_to :integration
  belongs_to :integration_instance
  enum field_type: { text: 0, string: 1, date: 2, autocomplete: 3, multi_select: 4, mcq: 5, confirmation: 6, employment_status: 7, social_security_number: 8, social_insurance_number: 9}

  attr_encrypted_options.merge!(:encode => true)
  attr_encrypted :new_value, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']
  scope :by_custom_field_name, -> (field_name) { where(field_name: field_name).where.not(custom_field_id: nil).order('created_at desc')}
  scope :by_field_name, -> (field_name) { where(field_name: field_name).where(custom_field_id: nil).order('created_at desc')}
  validates_with HistoryCompanyValidator
end
