class CustomSection < ApplicationRecord
  belongs_to :company
  has_many :custom_fields
  has_many :approval_chains, as: :approvable, dependent: :destroy
  has_many :custom_section_approvals , dependent: :destroy

  accepts_nested_attributes_for :approval_chains, allow_destroy: true
  enum section: { profile: 0, personal_info: 1, private_info: 2, additional_fields: 3 }
  SECTION_NAME_MAPPER = {profile: 'Profile Information', personal_info: 'Personal Information', private_info: 'Private Information', additional_fields: 'Additional Information'}

  after_update :manage_approval_type_requested_sections, if: Proc.new { |custom_section| custom_section.is_approval_required_before_last_save.present? && custom_section.is_approval_required.blank? }

  def manage_approval_type_requested_sections
    self.custom_section_approvals.where(state: CustomSectionApproval.states[:requested]).destroy_all
  end

  def section_name
    SECTION_NAME_MAPPER[self.section.to_sym] if self.section rescue ''
  end
end
