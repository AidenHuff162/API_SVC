class GeneralDataProtectionRegulationForm < BaseForm

  attribute :id, Integer
  attribute :action_type, Integer
  attribute :action_period, Integer
  attribute :action_location, Array[String]
  attribute :edited_by_id, Integer
  attribute :company_id, Integer

  validates :action_type, :action_period, :edited_by_id, :company_id, presence: true
end
