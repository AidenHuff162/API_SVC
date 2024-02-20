module ManageUserUpdate
  extend ActiveSupport::Concern

  def reassign_manager_activities(old_manager_id, user_id, task_type, new_manager_id)
    user = current_company.users.find_by_id(user_id)
    if user.present?
      user.task_user_connections.joins(:task).where(tasks: {task_type: task_type}, state: 'in_progress', owner_id: old_manager_id).update_all(owner_id: new_manager_id)
      current_company.users.find_by_id(old_manager_id).try(:fix_counters)
      current_company.users.find_by_id(new_manager_id).try(:fix_counters)
    end
  end

end
