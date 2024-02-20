module ManageUserRoles
  extend ActiveSupport::Concern

  def assign_user_role(user_id, role_id)
    user = current_company.users.find_by(id: user_id)
    if user
      old_user_role = user.user_role
      user.update!(user_role_id: role_id)
      record_changes(user, old_user_role) if old_user_role.role_type == 'super_admin'
    end
    current_company.user_roles.find_by(id: role_id)
  end

  def record_changes(user, old_user_role)
    data = { changed_by_details: { user_id: current_user.id, user_name: current_user.full_name },
             affacted_user_details: { user_id: user.id, user_name: user.full_name },
             old_role: old_user_role.name, new_role: user.user_role.name, changed_time: current_company.time }
    create_log(current_company, 'Sarah role changed audit', data)
  end
end
