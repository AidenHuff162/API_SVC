module UserSerializer
  class Dashboard < People
    type :user

    attributes :start_date, :incomplete_documents_count, :complete_documents_count,
               :tasks_count, :outstanding_tasks_count, :total_tasks_count, :overdue_tasks_count,
               :progress, :termination_date, :last_day_worked, :division, :old_start_date

    def incomplete_documents_count
      object.incomplete_documents_count
    end

    def complete_documents_count
      object.total_document_count - incomplete_documents_count
    end

    def total_tasks_count
      object.user_tasks_count
    end

    def overdue_tasks_count
      TaskUserConnection.joins("INNER JOIN users ON users.id = task_user_connections.owner_id")
                        .where("user_id = ? AND task_user_connections.state = 'in_progress' AND due_date < ?", object.id, Date.today)
                        .count
    end

    def progress
      tasks = object.task_user_connections.joins("INNER JOIN users ON users.id = task_user_connections.owner_id").count
      docs = object.user_document_connections.count
      doc_reqs = object.paperwork_requests.where.not(state: 'draft').count
      activites = tasks + doc_reqs + docs

      activites_done = activites - (object.outstanding_tasks_count + incomplete_documents_count)
      perc = 100
      perc = (activites_done.to_f / activites) * 100 if activites > 0
      perc
    end

    def division
      begin
        if object.custom_field_values.present? && object.custom_field_values.joins(:custom_field).where(custom_fields: {name: "Division"}).present?
          object.custom_field_values.joins(:custom_field).where(custom_fields: {name: "Division"}).first
        end
      rescue Exception => e
      end
    end

  end
end
