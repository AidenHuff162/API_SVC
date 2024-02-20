class PermissionService

  def check_user_visibility(user, company, params)
    return true if user.user_role.role_type == 'super_admin'
    field = company.custom_fields.find_by(name: params[:field_name])
    if field.present?
      check_section_visibillity(user, field.section, params['user_id'].to_i)
    else
      field = (company.prefrences['default_fields'].select { |obj| obj['name'] == params[:field_name] }).first
      section = field['section']
      check_section_visibillity(user, section, params['user_id'].to_i)
    end
  end

  def check_section_visibillity(user, section, employee_id)
    if section == "profile"
      employee_permissions = user.user_role.permissions['platform_visibility']['profile_info'] == 'view_and_edit' if user.user_role.role_type == 'employee'
      manager_or_admin_permissions = user.user_role.permissions['own_platform_visibility']['profile_info'] == 'view_and_edit' if user.id == employee_id && is_manager_or_admin(user)
      raise CanCan::AccessDenied unless user.present? && (employee_permissions || manager_or_admin_permissions)
    else
      employee_permissions = user.user_role.permissions['employee_record_visibility'][section == "additional_fields" ? "additional_info" : section] == 'view_and_edit' if user.user_role.role_type == 'employee'
      manager_permissions  = user.user_role.permissions['employee_record_visibility'][section == "additional_fields" ? "additional_info" : section] == 'view_and_edit' || user.user_role.permissions['own_info_visibility'][section == "additional_fields" ? "additional_info" : section] == 'view_and_edit' || user.user_role.permissions['platform_visibility'][section] == 'view_and_edit' || user.user_role.permissions['own_platform_visibility'][section] == 'view_and_edit' if user.user_role.role_type == 'manager'
      admin_permissions    = user.user_role.permissions['employee_record_visibility'][section == "additional_fields" ? "additional_info" : section] == 'view_and_edit' || user.user_role.permissions['own_info_visibility'][section == "additional_fields" ? "additional_info" : section] == 'view_and_edit' || user.user_role.permissions['platform_visibility'][section] == 'view_and_edit' || user.user_role.permissions['own_platform_visibility'][section] == 'view_and_edit' || user.user_role.permissions['admin_visibility'][section] == 'view_and_edit' if user.user_role.role_type == 'admin'
      raise CanCan::AccessDenied unless user.present? && (employee_permissions || manager_permissions || admin_permissions)
    end
  end

  def isAdminVisibilityPermissionExists?(user)
    return (user.user_role && user.user_role.permissions && user.user_role.permissions['admin_visibility'] && (user.user_role.admin? || user.user_role.super_admin?))
  end

  def isOwnPlatformVisibilityPermissionExists?(user)
    return (user.user_role && user.user_role.permissions && user.user_role.permissions['platform_visibility'] && user.user_role.employee?)
  end

  def isManagerPlatformVisibilityPermissionExists?(user, employee)
    return false if !employee
    role_permission = user.user_role && user.user_role.permissions
    permission = (role_permission && user.user_role.permissions && ((user.id == employee.id && user.user_role.permissions['own_platform_visibility']) || (user.id != employee.id && user.user_role.permissions['platform_visibility'] && user.all_managed_users.count > 0)) && user.user_role.manager?)
    return false if !permission.present?

    if user.id != employee.id
      if user.user_role.direct?
        return user.managed_user_ids.include?(employee.id)
      else
        return user.cached_indirect_reports_ids.include?(employee.id) || user.managed_user_ids.include?(employee.manager_id)
      end
    else
      return true
    end
  end

  def isAdminPlatformVisibilityPermissionExists?(user, employee)
    return true if (user && employee && user.id == employee.id && user.user_role.admin? && user.user_role && user.user_role.permissions && user.user_role.permissions['own_platform_visibility'])

    permission = (user.user_role && user.user_role.permissions && user.user_role.permissions['platform_visibility'] && user.user_role.admin?)
    return false if !permission

    return true if permission && employee.nil?

    return (permission && checkPermissionLDE(user, employee))
  end

  def isAccountOwnerPlatformVisibilityPermissionExists?(user, employee)
    return true if user && employee && user.id == employee.id && user.user_role.super_admin?
    return user && (user.user_role && user.user_role.permissions && user.user_role.permissions['platform_visibility'] && user.user_role.super_admin?)
  end

  def checkAdminVisibility(user, sub_tab = nil, action_name = nil)
    raise CanCan::AccessDenied if !user
    if sub_tab.present?
      if %w[offboarding_page_index offboard_emails offboard_teams_locations offboard_workstreams].include? action_name
        raise CanCan::AccessDenied unless specialOffboardingPermissions user
      else
        raise CanCan::AccessDenied if !isAdminVisibilityPermissionExists?(user)
        permission = user.user_role.permissions['admin_visibility']["#{sub_tab}"]
        raise CanCan::AccessDenied if permission == 'no_access'
      end
    end
  end

  def onlyCheckAdminCanViewAndEditVisibility(user, sub_tab = nil, action_name = nil)
    return false if !user
    if sub_tab.present?
      if %w[offboarding_page_index offboard_emails offboard_workstreams offboard_snapshots update_state_draft_to_request].include? action_name
        raise CanCan::AccessDenied unless specialOffboardingPermissions user
      else
        return false unless isAdminVisibilityPermissionExists?(user)
        permission = user.user_role.permissions['admin_visibility']["#{sub_tab}"]
        return permission == 'view_and_edit'
      end
    end
    true
  end

  def checkAdminCanViewAndEditVisibility(user, sub_tab = nil, action_name = nil)
    onlyCheckAdminCanViewAndEditVisibility(user, sub_tab, action_name) ? true : (raise CanCan::AccessDenied)
  end

  def checkTaskPlatformVisibility(user, employee_id)
    checkPlatformVisibility('task', user, employee_id)
  end

  def checkCalendarPlatformVisibility(user, employee_id)
    checkPlatformVisibility('calendar', user, employee_id)
  end

  def checkDocumentPlatformVisibility(user, employee_id)
    checkPlatformVisibility('document', user, employee_id)
  end

  def checkTimeOffPlatformVisibility(user, employee_id)
    checkPlatformVisibility('time_off', user, employee_id)
  end

  def checkTableVisibility(user, employee_id)
    checkPlatformVisibility('table', user, employee_id)
  end

  def checkAdminCanViewAndEditProfileTemplate(user, employee_id)
    return false if !user
    return true if user.user_role&.super_admin?
    raise CanCan::AccessDenied unless adminCanUpdateProfileTemplate(user, employee_id)
  end

  def checkPlatformVisibility sub_tab, user, employee_id
    raise CanCan::AccessDenied if !user.present? || !user.user_role.present?
    raise CanCan::AccessDenied if sub_tab == 'calendar' && !user.company.enabled_calendar
    raise CanCan::AccessDenied if sub_tab == 'time_off' && !user.company.enabled_time_off
    raise CanCan::AccessDenied if sub_tab == 'table' && !user.company.is_using_custom_table && user.company.custom_tables.count <=0
    employee = User.find_by id: employee_id.to_i

    if user.user_role.employee? 
      if user.id == employee.id && isOwnPlatformVisibilityPermissionExists?(user)
        return if (user.user_role.permissions['platform_visibility'][sub_tab] != 'no_access')
      elsif user.id != employee.id && sub_tab == 'table'
        return if fetch_other_accessable_custom_tables(user.user_role, user, employee).present?
      end
      raise CanCan::AccessDenied

    elsif user.user_role.manager? && isManagerPlatformVisibilityPermissionExists?(user, employee)
      if user.id == employee.id
        return if ( user.user_role.permissions['own_platform_visibility'][sub_tab] != 'no_access')
      elsif user.id != employee.id
        return if ( user.user_role.permissions['platform_visibility'][sub_tab] != 'no_access')
      end
      raise CanCan::AccessDenied

    elsif user.user_role.super_admin? && isAccountOwnerPlatformVisibilityPermissionExists?(user, employee)
      return if ((employee && user.id == employee.id) || (((employee && user.id != employee.id) || !employee) && user.user_role.permissions['platform_visibility'][sub_tab] != 'no_access'))
      raise CanCan::AccessDenied

    elsif user.user_role.admin? && isAdminPlatformVisibilityPermissionExists?(user, employee)
      return if (employee && user.id == employee.id && user.user_role.permissions['own_platform_visibility'][sub_tab] != 'no_access') || (((employee && user.id != employee.id) || !employee) && user.user_role.permissions['platform_visibility'][sub_tab] != 'no_access')
      raise CanCan::AccessDenied
    end
    raise CanCan::AccessDenied
  end

  def checkPlatformVisibilityPtoAdjustment user, employee
    sub_tab = "time_off"
    raise CanCan::AccessDenied if !user.present? || !user.user_role.present?
    raise CanCan::AccessDenied if !user.company.enabled_time_off

    if user.user_role.employee?
      raise CanCan::AccessDenied

    elsif user.user_role.manager? && isManagerPlatformVisibilityPermissionExists?(user, employee)
      return if (user.id != employee.id && user.user_role.permissions['platform_visibility'][sub_tab] == 'view_and_edit')
      raise CanCan::AccessDenied

    elsif user.user_role.super_admin? && isAccountOwnerPlatformVisibilityPermissionExists?(user, employee)
      return if ((employee && user.id == employee.id) || ((employee && user.id != employee.id)  && user.user_role.permissions['platform_visibility'][sub_tab] == 'view_and_edit'))
      raise CanCan::AccessDenied

    elsif user.user_role.admin? && isAdminPlatformVisibilityPermissionExists?(user, employee)
      return if ((employee && user.id == employee.id && user.user_role.permissions['own_platform_visibility'][sub_tab] == 'view_and_edit') || ((employee && user.id != employee.id)  && user.user_role.permissions['platform_visibility'][sub_tab] == 'view_and_edit'))
      raise CanCan::AccessDenied
    end

    raise CanCan::AccessDenied
  end

  def retrieve_sections(permissions)
    return [] if permissions.blank?

    sections = []
    sections.push(CustomField.sections[:personal_info]) if permissions['personal_info'].present? && permissions['personal_info'] != 'no_access'
    sections.push(CustomField.sections[:additional_fields]) if permissions['additional_info'].present? && permissions['additional_info'] != 'no_access'
    sections.push(CustomField.sections[:private_info]) if permissions['private_info'].present? && permissions['private_info'] != 'no_access'
    puts sections
    return sections
  end

  def fetch_manager_accessable_custom_field_sections(user_role, user, employee, permissions)
    if user_role.direct_and_indirect?
      managed_user_ids = user.cached_indirect_reports_ids rescue []
      return (user.id == employee.manager_id || managed_user_ids.include?(employee.manager_id)) ? retrieve_sections(permissions.select { |key, value| value != 'no_access' }) : []
    else
      return (user.id == employee.manager_id) ? retrieve_sections(permissions.select { |key, value| value != 'no_access' }) : []
    end
  end

  def fetch_admin_accessable_custom_field_sections(user_role, user, employee, permissions)
    location_permission_level = user_role.location_permission_level && (user_role.location_permission_level.include?('all') || user_role.location_permission_level.include?(employee.location_id.try(:to_s)))
    team_permission_level = user_role.team_permission_level && (user_role.team_permission_level.include?('all') || user_role.team_permission_level.include?(employee.team_id.try(:to_s)))
    status_permission_level = user_role.status_permission_level && (user_role.status_permission_level.include?('all') || user_role.status_permission_level.include?(employee.employee_type))

    puts employee.team_id
    puts user_role.team_permission_level.inspect
    puts user_role.team_permission_level.include?(employee.team_id.try(:to_s))
    if location_permission_level && team_permission_level && status_permission_level
      puts permissions.select { |key, value| value != 'no_access' }
      return retrieve_sections(permissions.select { |key, value| value != 'no_access' })
    end

    return []
  end

  def fetch_own_accessable_custom_field_sections(user_role)
    if user_role.employee?
      permissions = user_role.permissions['employee_record_visibility'] rescue nil
      return [] if permissions.blank?

      return retrieve_sections(permissions.select { |key, value| value != 'no_access' })
    elsif user_role.admin? || user_role.manager?
      permissions = user_role.permissions['own_info_visibility'] rescue nil
      return [] if permissions.blank?

      return retrieve_sections(permissions.select { |key, value| value != 'no_access' })
    end
  end

  def fetch_others_accessable_custom_field_sections(user_role, user, employee)
    permissions = user_role.permissions['employee_record_visibility'] rescue nil
    return [] if permissions.blank? || user_role.employee?

    if user_role.manager?
      return fetch_manager_accessable_custom_field_sections(user_role, user, employee, permissions)
    elsif user_role.admin?
      return fetch_admin_accessable_custom_field_sections(user_role, user, employee, permissions)
    end
  end

  def fetch_accessable_custom_field_sections(current_company, user, employee_id)
    sections = []
    user_role = user.user_role

    return sections if user_role.blank? || employee_id.blank? # Role is not assigned to user or visiting profile id is not present
    return CustomField.sections.values if user.account_owner? && user_role.super_admin? # Super Admins have all the access

    employee = current_company.users.find_by_id(employee_id)
    return sections if employee.blank? # Visiting user does not exist

    if user.id == employee.id
      sections = fetch_own_accessable_custom_field_sections(user_role)
    elsif user.id != employee.id
      sections = fetch_others_accessable_custom_field_sections(user_role, user, employee)
    end

    return sections
  end

  def fetch_accessable_custom_tables(current_company, user, employee_id)
    custom_table_ids = []
    user_role = user.user_role

    return custom_table_ids if user_role.blank? || employee_id.blank? # Role is not assigned to user or visiting profile id is not present
    return current_company.custom_tables.pluck(:id) if user.account_owner? && user_role.super_admin? # Super Admins have all the access

    employee = current_company.users.find_by_id(employee_id)
    return custom_table_ids if employee.blank? # Visiting user does not exist

    if user.id == employee.id
      custom_table_ids = fetch_own_accessable_custom_tables(user_role)
    elsif user.id != employee.id
      custom_table_ids = fetch_other_accessable_custom_tables(user_role, user, employee)
    end

    return custom_table_ids
  end

  def fetch_own_accessable_custom_tables(user_role)
    if user_role.employee?
      permissions = user_role.permissions['own_role_visibility'] rescue nil
      return [] if permissions.blank?
      return permissions.select { |key, value| value != 'no_access' }.keys
    elsif user_role.admin? || user_role.manager?
      permissions = user_role.permissions['own_role_visibility'] rescue nil
      return [] if permissions.blank?
      return permissions.select { |key, value| value != 'no_access' }.keys
    end
  end

  def fetch_other_accessable_custom_tables(user_role, user, employee)
    permissions = user_role.permissions['other_role_visibility'] rescue nil
    return [] if permissions.blank?

    if user_role.manager?
      return fetch_manager_accessable_custom_tables(user_role, user, employee, permissions)
    elsif user_role.admin?
      return fetch_admin_accessable_custom_tables(user_role, user, employee, permissions)
    elsif user_role.employee?
      return fetch_employee_accessable_custom_tables(user_role, user, employee, permissions)
    end
  end

  def fetch_manager_accessable_custom_tables(user_role, user, employee, permissions)
    if user_role.direct_and_indirect?
      managed_user_ids = user.cached_indirect_reports_ids rescue []
      return (user.id == employee.manager_id || managed_user_ids.include?(employee.manager_id)) ? permissions.select { |key, value| value != 'no_access' }.keys : []
    else
      return (user.id == employee.manager_id) ? permissions.select { |key, value| value != 'no_access' }.keys : []
    end
  end

  def fetch_admin_accessable_custom_tables(user_role, user, employee, permissions)
    location_permission_level = user_role.location_permission_level && (user_role.location_permission_level.include?('all') || user_role.location_permission_level.include?(employee.location_id.try(:to_s)))
    team_permission_level = user_role.team_permission_level && (user_role.team_permission_level.include?('all') || user_role.team_permission_level.include?(employee.team_id.try(:to_s)))
    status_permission_level = user_role.status_permission_level && (user_role.status_permission_level.include?('all') || user_role.status_permission_level.include?(employee.employee_type))

    if location_permission_level && team_permission_level && status_permission_level
      return permissions.select { |key, value| value != 'no_access' }.keys
    end
    return []
  end

  def fetch_employee_accessable_custom_tables(user_role, user, employee, permissions)
    permissions.select { |key, value| value != 'no_access' }.keys
  end

  def fetch_reports_accessible_custom_tables(user, current_company)
    custom_table_ids = []
    user_role = user.user_role
    return custom_table_ids if user_role.blank?
    return current_company.custom_tables.pluck(:id) if user.account_owner? && user_role.super_admin?

    permissions = user.user_role.permissions["other_role_visibility"] rescue nil
    return [] if permissions.blank?

    return permissions.select { |key, value| value != 'no_access' }.keys
  end

  def can_cancel_past_request user, pto_request
    return true if user.user_role == "account_owner"
    return (user.user_role.permissions['platform_visibility']["time_off"] == "view_and_edit") if user.id != pto_request.user_id
    permission = get_own_time_off_permission(user)
    return permission == "view_and_edit"
  end

  def can_cancel_future_request user, pto_request
    return true if user.user_role == "account_owner"
    return (user.user_role.permissions['platform_visibility']["time_off"] == "view_and_edit") if user.id != pto_request.user_id
    permission = get_own_time_off_permission(user)
    return  isAdminVisibilityPermissionExists?(user) || permission != "no_access"
  end

  def can_assign_unassign_individual_policy user
    unless (user.role == 'admin' && user.user_role.permissions["platform_visibility"]["time_off"] == 'view_and_edit') || user.role == 'account_owner'
      raise CanCan::AccessDenied
    end
  end

  def can_unassign_individual_policy user_id, policy_id
    assigned_policy = AssignedPtoPolicy.includes(:pto_policy).where(user_id: user_id, pto_policy_id: policy_id).first
    if !assigned_policy.manually_assigned || assigned_policy.pto_policy.for_all_employees
      raise CanCan::AccessDenied
    end
  end

  def can_update_past_pto_request pto_request, current_user, params
    return true if current_user.role == "account_owner"
    company = current_user.company
    return (current_user.user_role.permissions["platform_visibility"]["time_off"] == "view_and_edit" ) if current_user.id != pto_request.user_id
    permission = get_own_time_off_permission(current_user)
    return isAdminVisibilityPermissionExists?(current_user) || (permission == "view_and_edit") || (pto_request.status == "pending" && pto_request.begin_date == company.time.to_date) || (pto_request.begin_date > company.time.to_date)
  end

  def can_approve_deny_pto_request pto_request, current_user
    return true if current_user.role == "account_owner"
    return false if current_user.user_role.role_type == "employee"
    return (current_user.user_role.permissions["platform_visibility"]["time_off"] != "no_access" ) if current_user.id != pto_request.user_id
    permission = get_own_time_off_permission(current_user)
    return isAdminVisibilityPermissionExists?(current_user) || (permission == "view_and_edit")
  end

  def canUpdatePermission role, current_user
    checkAdminCanViewAndEditVisibility(current_user, "permissions")
    raise CanCan::AccessDenied if role.role_type == "super_admin" ||  (current_user.user_role.role_type == "admin" && current_user.user_role_id == role.id)
  end

  def can_access_manager_form current_user, employee
    employee = User.find_by(id: employee)
    raise CanCan::AccessDenied if !(current_user.user_role.role_type == "super_admin" || (current_user.user_role.role_type == "manager" && employee.manager_id == current_user.id)) if employee.present?
  end

  def can_not_cancel_own_offboarding current_user, employee
    employee = User.find_by(id: employee)
    raise CanCan::AccessDenied if (current_user == employee) if employee.present?
  end

  def can_not_manage_own_rehire current_user, employee
     employee = User.find_by(id: employee)
    raise CanCan::AccessDenied if (current_user == employee) if employee.present?
  end

  def owner_can_manage(current_user, employee)
    return unless employee.present? && current_user.present?
    raise CanCan::AccessDenied unless %w[super_admin admin].include?(current_user.user_role.role_type)
  end

  def can_not_approve_invalid_person current_user, ctus
    raise CanCan::AccessDenied if !CtusApprovalChain.current_approval_chain(ctus).first&.approval_chain&.approval_ids.include?(current_user.id.to_s)
  end

  def can_not_approve_invalid_manager current_user, ctus
    current_approval_chain = CtusApprovalChain.current_approval_chain(ctus).first&.approval_chain
    raise CanCan::AccessDenied  if !(['manager', 'admin'].include?(current_user.user_role.role_type) && current_approval_chain&.approval_type == "manager" && CustomTableUserSnapshot.find_by_id(ctus).user.manager_level(current_approval_chain&.approval_ids[0]).id == current_user.id)
  end

  def can_not_approve_invalid_permission current_user, current_company, ctus
    if !CtusApprovalChain.current_approval_chain(ctus).first&.approval_chain.approval_ids.include? 'all'
      user_roles = current_company.user_roles.where(id: CtusApprovalChain.current_approval_chain(ctus).first&.approval_chain.approval_ids)
    else
      user_roles = current_company.user_roles.all
    end

    approval_ids =  user_roles.collect{ |user_role| user_role.try(:users).pluck(:id)}.flatten
    raise CanCan::AccessDenied if !approval_ids.include?(current_user.id)
  end

  def can_not_approve_invalid_coworker current_user, ctus
    current_approval_chain = CtusApprovalChain.current_approval_chain(ctus).first&.approval_chain
    raise CanCan::AccessDenied  if !(current_approval_chain&.approval_type == "coworker" && CustomTableUserSnapshot.find_by_id(ctus).user.get_custom_coworker(current_approval_chain&.approval_ids[0])&.id == current_user.id)
  end

  def can_not_delete_request_snapshot ctus_id
    return CanCan::AccessDenied if CustomTableUserSnapshot.find_by(id: ctus_id)&.requested?
  end

  def is_not_valid_person_for_approval_request_permissions current_user, company, approval_chain
    if !approval_chain.approval_ids.include? 'all'
      user_roles = company.user_roles.where(id: approval_chain.approval_ids)
    else
      user_roles = company.user_roles.all
    end

    approval_ids =  user_roles.collect{ |user_role| user_role.try(:users).pluck(:id)}.flatten
    return true if !approval_ids.include?(current_user.id)
  end

  def is_not_valid_person_for_approval_request_person current_user, approval_chain
    return true if !approval_chain&.approval_ids.include?(current_user.id.to_s)
  end

  def is_not_valid_person_for_approval_request_manager current_user, pto_request, approval_chain
    return true  if !(current_user.user_role.role_type != "employee" && approval_chain&.approval_type == "manager" && current_user.managed_user_ids.include?(pto_request.user_id))
  end

  def onlyCheckPeoplePageVisibility(current_user)
    user_role = current_user.user_role
    return true if user_role.role_type == 'super_admin'

    permissions = user_role.permissions

    if user_role.role_type != 'manager'
      return ['view_only', 'view_and_edit'].include?(permissions['platform_visibility'].try(:[], 'people').to_s)
    else
      return ['view_only', 'view_and_edit'].include?(permissions['own_platform_visibility'].try(:[], 'people').to_s)
    end
  end

  def checkPeoplePageVisibility(current_user)
    onlyCheckPeoplePageVisibility(current_user) ? true : (raise CanCan::AccessDenied)
  end

  def checkAccessibilityForOthers tab, user, employee_id
    return if user.id == employee_id || user.user_role.role_type == 'super_admin'
    raise CanCan::AccessDenied if (user.user_role.role_type == 'employee') || (user.user_role.permissions['platform_visibility'][tab] != 'view_and_edit')
  end

  def canAccessField current_user, employee, company, field_name
    field = company.prefrences["default_fields"].select {|field| field['name'] == field_name }[0]
    return false unless field.present?
    section = field['section']
    fetch_accessable_custom_field_sections(company, current_user, employee).include?(CustomField.sections[section])
  end

  def canAccessAssignedTasksCount(user, employee_id)
    begin
      checkTaskPlatformVisibility(user, employee_id)
      return true
    rescue CanCan::AccessDenied => e
      return false
    end
  end

  def canAccessAssignedDocumentsCount(user, employee_id)
    begin
      checkDocumentPlatformVisibility(user, employee_id)
      return true
    rescue CanCan::AccessDenied => e
      return false
    end
  end

  private

  def manager_can_update_past_request pto_request, current_user, params
    # params.delete(:permission_bypass) if params[:permission_bypass]
    # fields_manager_can_update = ["id", "status", "approval_denial_date", "user_id", "approved_by_id"]
    current_user.managed_user_ids.include?(pto_request.user_id)
  end

  def get_own_time_off_permission user
    return is_manager_or_admin(user) ? user.user_role.permissions["own_platform_visibility"]["time_off"]  : user.user_role.permissions["platform_visibility"]["time_off"]
  end


  def is_manager_or_admin user
    ['manager', 'admin'].include?(user.user_role.role_type)
  end

  def specialOffboardingPermissions user
    (user.user_role.super_admin? || canManagerOffboard(user) || canAdminOffboard(user)) rescue false
  end

  def canManagerOffboard user
    user.user_role.manager? && user.user_role.permissions["other_role_visibility"]["can_offboard_reports"]
  end

  def canAdminOffboard user
    user.user_role.admin? && (user.user_role.permissions['admin_visibility']['dashboard'] == 'view_and_edit' || user.user_role.permissions['platform_visibility']['can_offboard_users'])
  end

  def adminCanUpdateProfileTemplate user, employee_id
    return false unless user.user_role&.admin?
    if user.id == employee_id
      permission = user.user_role.permissions.dig('own_platform_visibility', 'profile_info')
    else
      permission = user.user_role.permissions.dig('platform_visibility', 'profile_info')
    end
    employee = User.find_by(id: employee_id)
    return true if permission == 'view_and_edit' && checkPermissionLDE(user, employee)
  end

  def checkPermissionLDE user, employee
    location_level = (employee && user.user_role.location_permission_level.present? && (user.user_role.location_permission_level.include?('all') || user.user_role.location_permission_level.include?(employee.location_id.try(:to_s))))
    team_level = (employee && user.user_role.team_permission_level.present? && (user.user_role.team_permission_level.include?('all') || user.user_role.team_permission_level.include?(employee.team_id.try(:to_s))))
    status_level = (employee && user.user_role.status_permission_level.present? && (user.user_role.status_permission_level.include?('all') || user.user_role.status_permission_level.include?(employee.employee_type)))
    return (location_level && team_level && status_level)
  end
end
