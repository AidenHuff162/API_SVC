module UserSerializer
  class Team < ActiveModel::Serializer
    type :user

    attributes :id, :picture, :first_name, :last_name, :preferred_name, :preferred_full_name, :title, :current_stage,
      :outstanding_owner_tasks_count, :outstanding_tasks_count, :is_form_completed_by_manager, :state, :pending_pto_requests_length,
      :start_date, :pending_tasks, :location, :ooo_pto_request, :incomplete_tasks_count

    def pending_pto_requests_length
      if object.company.enabled_time_off
        pto_requests = object.pto_requests.pending_requests.where(partner_pto_request_id: nil).size
      end
    end

    def pending_tasks
    	TaskUserConnection.where("? IN (user_id, owner_id) AND state = ? AND before_due_date > ?", object.id, 'in_progress', Date.today).count
    end

    def location
      object.location.try(:name) || "Unassigned"
    end

    def ooo_pto_request
      object.is_on_leave?
    end

    def incomplete_tasks_count
      TaskUserConnection.incomplete_task_count(object.id)
    end

  end
end
