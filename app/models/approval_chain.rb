class ApprovalChain < ApplicationRecord
  acts_as_paranoid
  belongs_to :custom_table
  belongs_to :custom_section
  belongs_to :pto_policy
  belongs_to :custom_section_approval
  has_many :cs_approval_chains, dependent: :destroy
  has_many :ctus_approval_chains, dependent: :destroy
  has_many :approval_requests, dependent: :destroy

  enum approval_type: { manager: 0, person: 1, permission: 2, individual: 3, coworker: 4, requestor_manager: 5 }
  validates_with ApprovalIdsLengthValidator

  default_scope { order(id: :asc) }

end
