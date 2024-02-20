class CustomSectionApprovalPermissionService
  def can_view_approval_values(current_user, cs_approval_id, current_company, employee_id)
    
    custom_section_approval = get_custom_section_approval(cs_approval_id, current_company)
    approval_chain_list = custom_section_approval.cs_approval_chain_list
    employee = current_company.users.find_by_id(employee_id)
    approval_request_section = CustomField.sections[custom_section_approval.custom_section.section]
    accessible_sections = PermissionService.new.fetch_accessable_custom_field_sections(current_company, current_user, employee.id)
    access_granted = false
    
    approval_chain_list.each do |chain|
      return access_granted = true if current_user.admin? || current_user.account_owner? || chain['approver_id'].present? && chain['approver_id'] == current_user.id || chain['approver_permission_ids'].present? && chain['approver_permission_ids'].include?(current_user.user_role_id.to_s)
    end
    access_granted = true if custom_section_approval.requester_id == current_user.id
    
    access_granted = true if employee.manager_id == current_user.id && accessible_sections.include?(approval_request_section)

    access_granted = true if access_granted == false && accessible_sections.include?(approval_request_section)
    access_granted = true unless PermissionService.new.checkPlatformVisibility("profile_info", current_user, employee.id)

    raise CanCan::AccessDenied unless access_granted
  end

  def can_update_approval(current_user, cs_approval_id, current_company, is_destroy = false)
    custom_section_approval = get_custom_section_approval(cs_approval_id, current_company)
    approvers = custom_section_approval.approvers
    access_granted = false
    return true if is_destroy && custom_section_approval.requester_id == current_user.id
    return access_granted = true if current_user.admin? || current_user.account_owner? || approvers['approver_ids'].present? && approvers['approver_ids'].include?(current_user.id)
    raise CanCan::AccessDenied unless access_granted
  end

  def get_custom_section_approval(cs_approval_id, current_company)
    CustomSectionApproval.joins(:custom_section).where(custom_section_approvals: {id: cs_approval_id}).where(custom_sections: {company_id: current_company.id})&.take
  end
end
