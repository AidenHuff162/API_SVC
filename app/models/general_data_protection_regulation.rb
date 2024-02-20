class GeneralDataProtectionRegulation < ApplicationRecord
  include GdprManagement

  belongs_to :company
  belongs_to :edited_by, class_name: 'User'

  validates :company_id, uniqueness: true
  validates_inclusion_of :action_period, in: [1, 2, 3, 4, 5, 6, 7], allow_nil: false

  before_save :remove_blank_from_action_location
  after_create { enforce_general_data_protection_regulation(self) if action_location.reject(&:blank?).present? }
  after_update { update_enforced_general_data_protection_regulation(self, true) if saved_change_to_action_location? }
  after_update { update_enforced_general_data_protection_regulation(self) if saved_change_to_action_period? }

  enum action_type: { anonymize: 0, remove: 1 }

  private

  def remove_blank_from_action_location
    self.action_location = self.action_location.reject(&:blank?)
  end
end
