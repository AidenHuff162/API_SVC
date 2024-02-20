module ApprovalChainOperations
  extend ActiveSupport::Concern

  def approvers
    user_data = {}
    user_data["approver_names"] = []
    user_data["approver_ids"] = []
    user_data["approvers_emails"] = []
    
    approval = ApprovalRequest.current_approval_request(self.id)[0]
    company = self.user.company
    if approval&.requested?
      if approval.approval_chain.permission?
        if !approval.approval_chain.approval_ids.include? 'all'
          user_roles = company.user_roles.where(id: approval.approval_chain.approval_ids)
        else
          user_roles = company.user_roles.all
        end
        user_data["approver_names"].concat user_roles.collect(&:name)
        user_data["approver_ids"].concat user_roles.collect{ |user_role| user_role.try(:users).pluck(:id)}.flatten
        user_data["approvers_emails"].concat user_roles.collect{|role| role.users.map{|user| user.email.present? ?  user.email : user.personal_email}}.flatten
        return user_data
      
      elsif approval.approval_chain.person?
        user = company.users.find_by(id: approval.approval_chain.approval_ids)
        if user.present?
          user_data["approver_names"].push user.try(:preferred_full_name)
          user_data["approver_ids"].push user.try(:id)
          user_data["approvers_emails"].push user.email.present? ? user.email : user.personal_email
        end
        return user_data

      elsif approval.approval_chain.manager?
        user = self.user
        if user.present?
          user_data["approver_names"].push user.manager.try(:preferred_full_name)
          user_data["approver_ids"].push user.manager.try(:id)
          user_data["approvers_emails"].push user.manager.try(:email).present? ? user.manager.try(:email) : user.manager.try(:personal_email)
        end
        return user_data
      end
    end
  end
end
