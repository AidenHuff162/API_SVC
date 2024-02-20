class ApprovalRequest < ApplicationRecord
  belongs_to :approvable_entity, polymorphic: true
  belongs_to :approval_chain
  
  attr_accessor :send_request_email
  
  enum request_state: { denied: 0, requested: 1,  approved: 2}
  
  scope :current_approval_request, -> (pto_id) { where("approvable_entity_id = ? AND request_state = ?", pto_id, ApprovalRequest.request_states[:requested]).order(id: :asc).limit(1) }
  
  before_destroy :set_send_request_email, if: Proc.new {|ar| ar.approvable_entity_type == "PtoRequest" && ar.destroyed_by_association.present? && ar.destroyed_by_association.foreign_key == 'approval_chain_id'}
  
  after_destroy :send_pto_request_emails, if: Proc.new {|ar| ar.approvable_entity_type == "PtoRequest" && ar.destroyed_by_association.present? && ar.destroyed_by_association.foreign_key == 'approval_chain_id'}
  private
  
  def set_send_request_email
    pto = self.approvable_entity
    self.send_request_email =  pto.present? && self.id == ApprovalRequest.current_approval_request(pto.id)[0]&.id ? true : false
    return true
  end
  
  def send_pto_request_emails
    if self.send_request_email
      if ApprovalRequest.current_approval_request(self.approvable_entity_id)[0].present?
        self.approvable_entity.send_mail_to_approval_request_users
      else
        self.approvable_entity.update(status: 'approved', approval_deleted: true) if self.approvable_entity.status == "pending"
      end
    end
  end
end
