class WorkstreamsCollection < BaseCollection
  include SmartAssignmentFilters
  private

  def relation
    if params[:transition] || params[:workspace_id] || params[:with_deleted_workstream_tasks]
      @relation ||= Workstream.with_deleted.all
    else
      @relation ||= Workstream.all
    end
  end

  def ensure_filters
    company_filter
    onboarding_plan_filter
    exclude_empty_worksreams_filter
    name_filter
    hide_workspace_tasks_filter
    workspace_filter
    user_filter
    sorting_filter
    owner_filter
    task_owner_filter
    exclude_by_user_id_filter
    exclude_by_owner_id_filter
    process_type_filter
    sa_filter
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def exclude_empty_worksreams_filter
    filter { |relation| relation.where.not(tasks_count: 0) } if params[:exclude_empty_worksreams] && !params[:with_deleted_workstream_tasks]
  end

  def hide_workspace_tasks_filter
    filter do |relation|
      relation.where.not("owner_connections.owner_type = 1")
    end if params[:hide_workspace_tasks] && params[:owner_id]
  end

  def name_filter
    filter do |relation|
      pattern = "%#{params[:term].to_s.downcase}%"
      relation.where("workstreams.name ILIKE ?", pattern)
    end if params[:term]
  end

  def workspace_filter
    filter do |relation|
      relation.joins("INNER JOIN tasks AS workspace_tasks ON workspace_tasks.workstream_id = workstreams.id")
              .joins("INNER JOIN task_user_connections AS workspace_connections ON workspace_connections.task_id = workspace_tasks.id AND workspace_connections.deleted_at IS NULL")
              .joins("INNER JOIN workspaces ON workspaces.id = workspace_connections.workspace_id AND workspaces.id = #{params[:workspace_id]}")
              .uniq
    end if params[:workspace_id]
  end

  def user_filter
    filter do |relation|
      relation.joins("INNER JOIN tasks AS user_tasks ON user_tasks.workstream_id = workstreams.id")
              .joins("INNER JOIN task_user_connections AS user_connections ON user_connections.task_id = user_tasks.id AND user_connections.deleted_at IS NULL")
              .joins("INNER JOIN users ON users.id = user_connections.owner_id")
              .where('user_connections.user_id = ? OR user_connections.owner_id = ? AND user_connections.state != ?', params[:user_id], params[:user_id], 'draft')
              .uniq
    end if params[:user_id]
  end

  def sorting_filter
    if params[:sort_column] && params[:sort_order]
      order_in = params[:sort_order].downcase == 'asc' ? 'asc' : 'desc'

      if params[:sort_column] == 'modified_by'
        filter { |relation| relation.reorder("updated_at #{order_in}") }

      elsif params[:sort_column] == 'name'
        filter { |relation| relation.reorder("name #{order_in}") }
      end
    end
  end

  def owner_filter
    if params[:owner_id]
      if params[:active_tasks]
        filter do |relation|
          relation.joins("INNER JOIN tasks AS owner_tasks ON owner_tasks.workstream_id = workstreams.id")
                  .joins("INNER JOIN task_user_connections AS owner_connections ON owner_connections.task_id = owner_tasks.id AND owner_connections.deleted_at IS NULL")
                  .joins("INNER JOIN users ON users.id = owner_connections.user_id")
                  .where.not(owner_tasks: {task_type: '4'})
                  .where(owner_connections: {owner_id: params[:owner_id]})
                  .uniq
        end
      elsif !params[:transition] || (params[:transition] && params[:transition] == 'latest')
        filter do |relation|
          relation.joins("INNER JOIN tasks AS owner_tasks ON owner_tasks.workstream_id = workstreams.id")
                  .joins("INNER JOIN task_user_connections AS owner_connections ON owner_connections.task_id = owner_tasks.id AND owner_connections.deleted_at IS NULL")
                  .joins("INNER JOIN users ON users.id = owner_connections.user_id")
                  .where.not(owner_tasks: {task_type: '4'})
                  .where(owner_connections: {owner_id: params[:owner_id]})
                  .where("users.state <> 'inactive' AND users.current_stage <> #{User.current_stages[:incomplete]} AND (users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO)
                  .uniq
        end
      elsif params[:transition] == 'historical'
        filter do |relation|
          relation.joins("INNER JOIN tasks AS owner_tasks ON owner_tasks.workstream_id = workstreams.id")
                  .joins("INNER JOIN task_user_connections AS owner_connections ON owner_connections.task_id = owner_tasks.id")
                  .joins("INNER JOIN users ON users.id = owner_connections.user_id")
                  .where.not(owner_tasks: {task_type: '4'})
                  .where(owner_connections: {owner_id: params[:owner_id]})
                  .where("users.current_stage <> #{User.current_stages[:incomplete]}")
                  .uniq
        end
      end
    end
  end

  def task_owner_filter
    filter do |relation|
      relation.joins(:tasks)
              .where(tasks: {owner_id: params[:task_owner_id]})
              .uniq
    end if params[:task_owner_id]
  end

  def exclude_by_user_id_filter
    filter { |relation| relation.joins(:tasks).where("NOT EXISTS(SELECT * FROM task_user_connections WHERE task_user_connections.task_id = tasks.id AND task_user_connections.user_id = ? AND deleted_at IS NULL AND state = 'in_progress')", params[:exclude_by_user_id]).uniq } if params[:exclude_by_user_id]
  end

  def exclude_by_owner_id_filter
    filter { |relation| relation.joins(:tasks).where("NOT EXISTS(SELECT * FROM task_user_connections WHERE task_user_connections.task_id = tasks.id AND task_user_connections.owner_id = ? AND deleted_at IS NULL AND state = 'in_progress')", params[:exclude_by_owner_id]).uniq } if params[:exclude_by_owner_id]
  end

  def process_type_filter
    if params[:process_type]
      filter { |relation| relation.joins(:process_type).where("process_types.name = ?", params[:process_type]) }
    end
  end

  def sa_filter
    filter { |relation| relation.where(sa_filters) } if params[:location_id] || params[:team_id] || params[:employment_status_option] || params[:employment_type] || params[:custom_groups]
  end

  def onboarding_plan_filter
    filter { |relation| relation.joins(:process_type).where('LOWER(process_types.name) IN (?)', ['onboarding', 'offboarding']) } if params[:onboarding_plan] && !params[:custom_tasks_workstream]
  end

end
