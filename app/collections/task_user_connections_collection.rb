class TaskUserConnectionsCollection < BaseCollection
  private

  def relation
    if (params[:transition] && params[:transition] == 'historical') || (params[:include_deleted] && params[:include_deleted] == true)
      @relation ||= TaskUserConnection.with_deleted.all
    else
      @relation ||= TaskUserConnection.all
    end
  end

  def ensure_filters
    company_filter
    workspace_filter
    workspace_status_filter
    owner_filter
    workspace_member_filter
    user_filter
    exclude_users_filter
    workstream_filter
    not_pending_filter
    state_filter
    all_tasks_filter
    overdue_count_filter
    overdue_filter
    pending_filter
    term_filter
    sorting_filter
    count_filter
    unique_user_count_filter
    task_filter
    multiple_task_count_filter
    multiple_workspace_task_count_filter
    task_due_date_range_filter
    team_filter
    location_filter
    employee_type_filter
    tasks_ids_filter
    survey_id_filter
    incomplete_users_filter
    multiple_custom_groups_filter
    multiple_custom_groups_employee_type_filter
    id_filter
  end

  def company_filter
    filter do |relation|
      relation.joins("INNER JOIN tasks ON tasks.id = task_user_connections.task_id")
              .joins("INNER JOIN workstreams ON workstreams.id = tasks.workstream_id")
              .where(workstreams: {company_id: params[:company_id]})
    end if params[:company_id]
  end

  def workspace_member_filter
    filter do |relation|
      relation.where(owner_type: 0)
    end if params[:workspace_task_filter] && !params[:user_id]
  end

  def incomplete_users_filter
    filter do |relation|
      relation.joins("INNER JOIN users AS invited_task_receivers ON invited_task_receivers.id = task_user_connections.user_id AND invited_task_receivers.current_stage <> #{User.current_stages[:incomplete]}")
    end if params[:hide_incomplete_user]
  end

  def workspace_filter
    filter do |relation|
      relation.where(workspace_id: params[:workspace_id])
    end if params[:workspace_id]
  end

  def workspace_status_filter
    if params[:status]
      filter do |relation|
        relation.where(owner_type: TaskUserConnection.owner_types[:workspace])
      end if params[:status] == 'open'

      filter do |relation|
        relation.where(owner_type: TaskUserConnection.owner_types[:individual])
      end if params[:status] == 'assigned'

      filter { |relation| relation.where("due_date < ?", Date.today) } if params[:status] == 'overdue'
    end
  end

  def exclude_users_filter
    filter do |relation|
      relation.joins("INNER JOIN users AS task_owner ON task_owner.id = task_user_connections.owner_id AND task_owner.state <> 'inactive' AND task_owner.current_stage <> #{User.current_stages[:incomplete]}")
    end if params[:exclude_users_state]
  end

  def user_filter
    filter do |relation|
      relation.joins("INNER JOIN users AS owners ON task_user_connections.owner_id = owners.id").where("user_id = ? OR task_user_connections.owner_id = ?", params[:user_id], params[:user_id])
    end if params[:user_id]
  end

  def owner_filter
    if params[:owner_id]
      if !params[:transition] || (params[:transition] && params[:transition] == 'latest')
        filter do |relation|
          relation.joins(:user).where(owner_id: params[:owner_id], owner_type: 'individual')
                  .where("users.current_stage <> #{User.current_stages[:incomplete]} AND (users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO)
                  .where.not(tasks: {task_type: '4'})
        end
      elsif params[:transition] == 'historical'
        filter do |relation|
          relation.joins("INNER JOIN users ON users.id = task_user_connections.owner_id").where(owner_id: params[:owner_id])
                  .where("users.current_stage <> #{User.current_stages[:incomplete]}")
                  .where.not(tasks: {task_type: '4'})
        end
      end
    end
  end

  def workstream_filter
    filter do |relation|
      relation.where(workstreams: {id: params[:workstream_id]})
    end if params[:workstream_id]
  end

  def not_pending_filter
    filter { |relation| relation.where("(before_due_date > ? AND task_user_connections.state = 'completed') OR before_due_date <= ? OR before_due_date IS NULL", Date.today, Date.today) } if params[:not_pending] && params[:state]
  end

  def state_filter
    filter { |relation| relation.where(state: params[:state]) } if params[:state]
  end

  def all_tasks_filter
    filter { |relation| relation.where.not(state: 'draft') } unless params[:state]
  end

  def overdue_count_filter
    filter { |relation| relation.where("due_date < ?", Date.today + params[:overdue_in].to_i.days) } if params[:overdue_in]
  end

  def overdue_filter
    filter { |relation| relation.where("due_date < ?", Date.today).where(state: 'in_progress') } if params[:overdue] && !(params[:state] == 'in_progress' && params[:workflow_report])
  end

  def pending_filter
    filter { |relation| relation.where("before_due_date > ?", Date.today) } if params[:pending]
  end

  def term_filter
    if params[:term]
      ids = []
      pattern = params[:term].to_s.downcase
      relation.each {|a| a.task.name = a.get_task_name.downcase }
      relation.each {|a| ids.push(a.id) if a.task.name.include? pattern }

      pattern = "%#{pattern}%"
      owner_ids = relation.joins("INNER JOIN users AS task_users ON task_users.id = task_user_connections.owner_id").where(user_id: params[:user_id])
      .where("lower(TRIM(task_users.first_name)) LIKE :pattern OR lower(TRIM(task_users.last_name)) LIKE :pattern OR lower(TRIM(task_users.preferred_name)) LIKE :pattern OR CONCAT(lower(TRIM(task_users.first_name)),\' \',lower(TRIM(task_users.last_name))) LIKE :pattern OR CONCAT(lower(TRIM(task_users.preferred_name)),\' \',lower(TRIM(task_users.last_name))) LIKE :pattern", pattern: pattern).pluck(:id)

      filter { |relation| relation.where(id: ids|owner_ids) }
    end
  end


  def sorting_filter
    if params[:order_column] && params[:order_in]
      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'

      if params[:order_column] == 'due_date'
        filter { |relation| relation.reorder("task_user_connections.due_date #{order_in}, task_user_connections.id asc") }

      elsif params[:order_column] == 'completion_date'
        filter { |relation| relation.reorder("task_user_connections.completed_at #{order_in}, task_user_connections.id asc") }

      elsif params[:order_column] == 'employee' && params[:term_owner_id]
        filter do |relation|
          relation.joins("INNER JOIN users AS task_users ON task_users.id = task_user_connections.owner_id")
          .order("task_users.preferred_full_name #{order_in}, task_user_connections.due_date #{order_in}")
        end

      elsif params[:order_column] == 'employee' && params[:term_user_id]
        filter do |relation|
          relation.joins("INNER JOIN users AS task_receivers ON task_receivers.id = task_user_connections.owner_id")
          .order("task_receivers.preferred_full_name #{order_in}, task_user_connections.due_date #{order_in}")
        end

      elsif params[:order_column] == 'task_name'
        filter { |relation| relation.reorder("LOWER(tasks.sanitized_name) #{order_in}") }
      end
    end
  end

  def count_filter
    filter { |relation| relation.count } if params[:count]
  end

  def unique_user_count_filter
    filter { |relation| relation.pluck(:user_id).uniq.count } if params[:unique_user_count]
  end

  def task_filter
    filter { |relation| relation.where(task_id: params[:task_id], owner_id: params[:owner_id]) } if params[:task_id]
  end

  def multiple_task_count_filter
    filter do |relation|
      relation.where('task_user_connections.deleted_at IS NULL').select("
        SUM (task_user_connections.id) AS total_tasks,
        SUM (CASE WHEN task_user_connections.state = 'completed' THEN 1 ELSE 0 END) AS completed_tasks_count,
        SUM (CASE WHEN task_user_connections.state = 'in_progress' AND (before_due_date IS NULL OR before_due_date <= '#{Date.today}') THEN 1 ELSE 0 END) AS in_complete_count,
        SUM (CASE WHEN task_user_connections.state = 'in_progress' AND (before_due_date IS NULL OR before_due_date <= '#{Date.today}') AND due_date < '#{Date.today}'  THEN 1 ELSE 0 END) AS overdue_tasks_count,
        SUM (CASE WHEN task_user_connections.state = 'in_progress' AND before_due_date > '#{Date.today}' THEN 1 ELSE 0 END) AS pending_tasks_count
      ")
    end if params[:multiple_task_count]
  end

  def multiple_workspace_task_count_filter
    filter do |relation|
      relation.select("
        SUM (task_user_connections.id) AS total_tasks,
        SUM (CASE WHEN task_user_connections.owner_type = 1 AND task_user_connections.state = 'in_progress' THEN 1 ELSE 0 END) AS open_task_count,
        SUM (CASE WHEN task_user_connections.owner_type = 0 AND task_user_connections.state = 'in_progress' THEN 1 ELSE 0 END) AS assigned_tasks_count,
        SUM (CASE WHEN task_user_connections.state = 'in_progress' AND (before_due_date IS NULL OR before_due_date <= '#{Date.today}') AND due_date < '#{Date.today}'  THEN 1 ELSE 0 END) AS overdue_tasks_count,
        SUM (CASE WHEN task_user_connections.state = 'completed' THEN 1 ELSE 0 END) AS completed_tasks_count
      ")
    end if params[:multiple_workspace_task_count]
  end

  def task_due_date_range_filter
    filter { |relation| relation.where('due_date BETWEEN ? AND ?', params[:due_date_start_range], params[:due_date_end_range]) } if params[:due_date_start_range] and params[:due_date_end_range]
  end

  def team_filter
    filter do |relation|
      relation.joins(:owner).where(users: {team_id: params[:team_id]})
    end if params[:team_id]
  end

  def location_filter
    filter do |relation|
      relation.joins(:owner).where(users: {location_id: params[:location_id]})
    end if params[:location_id]
  end

  def employee_type_filter
    if params[:company_id] && params[:employee_type] && params[:employee_type] != 'All Employee Status' && !params[:multiple_custom_groups]
      filter { |relation| relation.joins(:user => {:custom_field_values => [custom_field_option: :custom_field]}).where("custom_fields.company_id = ? AND custom_fields.field_type = ? AND custom_field_options.option IN (?)", params[:company_id], 13, params[:employee_type]) }
    end
  end

  def tasks_ids_filter
    filter { |relation| relation.where(task_id: params[:tasks_ids]) } if params[:workflow_report]
  end

  def survey_id_filter
    filter { |relation| relation.where(tasks: {survey_id: params[:survey_id]}).where.not(owner_id: nil) } if params[:survey_report]
  end

  def multiple_custom_groups_filter
    if params[:multiple_custom_groups] && params[:multiple_custom_groups].length > 0 && !params[:employee_type]
      a = filter { |relation| relation.joins(:user => {:custom_field_values => [custom_field_option: :custom_field]}) }
      string1 = ""
      a = filter { |relation| relation.joins(:user => {:custom_field_values => [custom_field_option: :custom_field]}) }
      params[:multiple_custom_groups].each do |filter|
        string1 = "(custom_field_values.custom_field_id = #{filter[:custom_field_id]} AND custom_field_values.custom_field_option_id IN (#{filter[:custom_field_option_id].reject(&:blank?).join(',')}))"
        a = a  & relation.where(string1)
      end
      filter { |relation| relation  & a}
    end
  end

  def multiple_custom_groups_employee_type_filter
    if params[:multiple_custom_groups] && params[:multiple_custom_groups].length > 0 && params[:employee_type]
      filter { |relation| relation.joins(:user => {:custom_field_values => [custom_field_option: :custom_field]}) }
      string1 = ""
      string2 = ""
      a = filter { |relation| relation.joins(:user => {:custom_field_values => [custom_field_option: :custom_field]}) }
      params[:multiple_custom_groups].each do |filter|
        string1 = "(custom_field_values.custom_field_id = #{filter[:custom_field_id]} AND custom_field_values.custom_field_option_id IN (#{filter[:custom_field_option_id].reject(&:blank?).join(',')}))"
        a = a  & relation.where(string1)
      end
      string2 = "custom_fields.company_id = #{params[:company_id]} AND custom_fields.field_type = 13 AND custom_field_options.option IN (?)"
      filter { |relation| a  & relation.where(string2,params[:employee_type])}
    end
  end

  def id_filter
    filter { |relation| relation.where(id: (params[:connection_id].to_i)) } if params[:connection_id]
  end
end
