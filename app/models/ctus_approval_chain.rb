class CtusApprovalChain < ApplicationRecord
  acts_as_paranoid

  belongs_to :custom_table_user_snapshot
  belongs_to :approval_chain
  belongs_to :approved_by, class_name: 'User'

  attr_accessor :previous_approval_chain
  
  enum request_state: { denied: 0, requested: 1,  approved: 2, skipped: 3 }
  
  scope :current_approval_chain, -> (ctus_id) { where("custom_table_user_snapshot_id = ? AND request_state = ?", ctus_id, CtusApprovalChain.request_states[:requested]).order(id: :asc).limit(1) }
  
  before_destroy :store_previous_chain
  after_destroy :send_request_emails, if: Proc.new { |ctus_approval_chain| ctus_approval_chain.requested? && ctus_approval_chain.destroyed_by_association&.foreign_key != 'custom_table_user_snapshot_id' && ctus_approval_chain.destroyed_by_association&.foreign_key == 'approval_chain_id' && ctus_approval_chain&.previous_approval_chain&.id != CtusApprovalChain.current_approval_chain(ctus_approval_chain.custom_table_user_snapshot_id).first&.id }
  after_update :update_approved_by_person, if: Proc.new { |ctus_approval_chain| ctus_approval_chain.approved?  && ctus_approval_chain.request_state_before_last_save == 'requested' }
  after_destroy :really_destroy_ctus_request, if: Proc.new { |ctus_approval_chain| !ctus_approval_chain.destroyed? && ctus_approval_chain.destroyed_by_association&.foreign_key != 'custom_table_user_snapshot_id'}

  private

  def store_previous_chain
    self.previous_approval_chain = CtusApprovalChain.current_approval_chain(self.custom_table_user_snapshot_id).first
  end
  
  def send_request_emails
    ctus = CtusApprovalChain.current_approval_chain(self.custom_table_user_snapshot_id).first.try(:custom_table_user_snapshot)
    
    if ctus && ctus.custom_table.is_approval_required.present? && ctus.custom_table.timeline?
      custom_table = ctus.try(:custom_table)
      user_approvers = ctus.approvers
      effective_date = ctus.effective_date.strftime('%b %d, %Y') rescue nil
      expiry_time = (ctus.created_at + custom_table.approval_expiry_time.days).strftime('%b %d, %Y') rescue nil
      user_approvers['approver_ids'].try(:each) do |approver_id|
        UserMailer.ctus_request_change_email_for_approvers(custom_table.try(:company_id), ctus.try(:requester_id), approver_id, ctus.user_id, custom_table.try(:name), effective_date, expiry_time).deliver_later!
      end
    elsif ctus.blank? && self&.custom_table_user_snapshot&.custom_table.present? && self&.custom_table_user_snapshot&.custom_table.is_approval_required.present? && self&.custom_table_user_snapshot&.ctus_approval_chains&.where(request_state: CtusApprovalChain.request_states[:requested]).blank?
      self.custom_table_user_snapshot.update(request_state: CustomTableUserSnapshot.request_states[:approved])
    end
  end

  def update_approved_by_person
    self.update_column(:approved_by_id, User.current.id)
  end

  def really_destroy_ctus_request
    self.really_destroy! 
  end
end
