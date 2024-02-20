def enable_own_role_visibility(user_role)
  user_role.permissions['own_role_visibility'].each do |key, value|
    user_role.permissions['own_role_visibility']["#{key}"] = "view_and_edit"
  end
  user_role.save!
end

def enable_other_role_visibility(user_role)
  user_role.permissions['other_role_visibility'].each do |key, value|
    user_role.permissions['other_role_visibility']["#{key}"] = "view_and_edit"
  end
  user_role.save!
end

def disable_other_role_visibility(user_role)
  user_role.permissions['other_role_visibility'].each do |key, value|
    user_role.permissions['other_role_visibility']["#{key}"] = "no_access"
  end
  user_role.save!
end

def disable_dashboard_access(user_role)
  user_role.permissions['admin_visibility']['dashboard'] = "no_access"
  user_role.save!
end
