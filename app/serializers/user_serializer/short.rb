module UserSerializer
  class Short < Base
    include Workspaces
    
    attributes :id, :title, :role, :state, :picture, :onboard_email,:email, :start_date,
               :team_id, :location_id, :manager_id, :outstanding_tasks_count, :tasks_count, :overdue_tasks, :is_onboarding,
               :employee_type, :termination_date, :bamboo_id, :last_changed, :buddy_id, :current_stage, :outstanding_owner_tasks_count,
               :personal_email, :preboarding_progress, :account_creator_id, :job_tier, :incomplete_documents_count,
               :overdue_tasks_count, :last_day_worked, :termination_type, :eligible_for_rehire,
               :account_creator, :team_name, :location_name, :onboarding_progress, :company_name,
               :last_logged_in_email, :user_role_id, :calendar_preferences, :company_buddy, :company_department,
               :user_role_name, :workspaces, :sign_in_count, :location, :display_name_format

    has_one :profile
    has_one :profile_image

    def is_onboarding
      object.onboarding?
    end

    def overdue_tasks
      count = 0
      task_owner_connections = TaskUserConnection.where(owner_id: object.id).where(state: 'in_progress').distinct.includes(:task)
      task_owner_connections.each do |tuc|
        if tuc.task.present?
          if (tuc.task.created_at + tuc.task.deadline_in.to_i.days) < Date.today
            count += 1
          end
        end
      end

      count
    end

    def location
      object.get_cached_location
    end

    def account_creator
      object.account_creator.present? ? object.account_creator : ''
    end

    def incomplete_documents_count
      object.incomplete_upload_request_count + object.incomplete_paperwork_count + object.co_signer_paperwork_count
    end

    def overdue_tasks_count
      TaskUserConnection.joins("INNER JOIN users ON users.id = task_user_connections.owner_id")
                        .where("user_id = ? AND task_user_connections.state = 'in_progress'", object.id)
                        .count
    end

    def team_name
      object.get_team_name
    end

    def location_name
      object.get_location_name
    end

    def company_name
      object.company.name
    end

    def display_name_format
      object.company.display_name_format
    end

    def company_buddy
      object.company.buddy
    end

    def company_department
      object.company.department.try(:singularize)
    end

    def employee_type
      object.employee_type
    end

    def user_role_name
      object.get_cached_role_name
    end

    def sign_in_count
      object.sign_in_count
    end
  end
end
