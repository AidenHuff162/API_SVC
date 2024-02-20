class CsApprovalChain < ApplicationRecord
  acts_as_paranoid
  
  belongs_to :custom_section_approval
  belongs_to :approval_chain
  belongs_to :approver, class_name: 'User'

  enum state: { denied: 0, requested: 1,  approved: 2, skipped: 3 }
  enum approver_type: { manager: 0, person: 1, permission: 2, individual: 3, coworker: 4, requestor_manager: 5 }

  scope :current_approval_chain, -> (cs_id) { where("custom_section_approval_id = ? AND state = ?", cs_id, CsApprovalChain.states[:requested]).order(id: :asc).limit(1) }
end
