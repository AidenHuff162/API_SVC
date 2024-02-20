class TasksCollection < BaseCollection
  def meta
    super.tap do |h|
      h[:tuc_counts] = tuc_counts if params[:tuc_counts].present?
    end
  end

  def total_open_tasks
    relation.length
  end

  def total_overdue_tasks
    relation.length
  end

  private

  def relation
    relation = @relation ||= Task.all.includes(:attachments)
    if ( user_params.present? &&
         user_params["dashboard_search"].present? &&
         user_params["sub_tab"].present? &&
         user_params["sub_tab"] == 'dashboard' &&
         params[:overdue].present? )
      relation.with_deleted
    else
      relation
    end
  end

  def ensure_filters
    company_filter
    superuser_filter
    user_filter
    owner_filter
    workstream_filter
    tuc_state_filter
    recent_employees_filter
    stage_filter
    team_filter
    location_filter
    pre_start_filter
    first_week_filter
    first_month_filter
    ramping_up_filter
    state_filter
    overdue_filter
    all_departures_filter
    current_stage_offboarded_filter
    current_stage_offboarding_weekly_filter
    current_stage_offboarding_monthly_filter
    active_employees_filter
    in_year_range_filter
    overdue_active_employees_filter
    overdue_in_year_range_filter
    sorting_filter
    name_filter

    searched_user_task_filter
    overdue_searched_user_task_filter
  end

  def in_year_range_filter
    if params[:users_params].present? && (user_params["max_year"].present? || user_params["min_year"].present?)
      min_year = user_params["min_year"].to_i if user_params["min_year"].present?
      max_year = user_params["max_year"].to_i if user_params["max_year"].present?
      filter do |relation|
        relation
          .joins(task_user_connections: :user)
          .where(task_user_connections: {state: 'in_progress'})
      end
      #individual cases
      filter {|relation| relation.where("users.start_date > ?", min_year.years.ago.to_date)} if !user_params["max_year"].present? && !user_params["combined_query"].present? && !user_params["retention"].present?#11
      filter {|relation| relation.where("users.start_date BETWEEN ? AND ?", max_year.years.ago.to_date + 1.day, (max_year - 1).years.ago.to_date)} if !user_params["min_year"].present? && !user_params["combined_query"].present? && !user_params["retention"].present? #12
      filter {|relation| relation.where("users.start_date < ?", max_year.years.ago.to_date + 1.day)} if !user_params["combined_query"].present? && user_params["retention"].present? #13

      #combined cases
      filter {|relation| relation.where("users.start_date > ?", max_year.years.ago.to_date)} if user_params["combined_query"].present? && !user_params["retention"].present? #11, 12
      filter {|relation| relation.where("(users.start_date BETWEEN ? AND ?) OR (users.start_date < ?)", min_year.years.ago.to_date + 1.day, (min_year - 1).years.ago.to_date, max_year.years.ago.to_date)} if user_params["combined_query"].present? && user_params["retention"].present? && user_params["min_year"].present? #11, 13
      filter {|relation| relation.where("users.start_date < ?", (max_year - 1).years.ago.to_date)} if user_params["combined_query"].present? && user_params["retention"].present? && !user_params["min_year"].present? #12, 13

      filter do |relation|
        relation
          .group(:id)
          .reorder('count_all desc')
          .select('tasks.*, COUNT(*) AS count_all')
      end
    end
  end

  def sorting_filter 
    if params[:sort_type]
      if params[:sort_type] == 'assignee_a_z'
        filter {|relation| relation.select("
         tasks.*, CASE WHEN tasks.task_type = '0'
              THEN task_users.preferred_full_name
              WHEN tasks.task_type = '1'
                THEN 'hire'
              WHEN tasks.task_type = '2'
                THEN 'manager'
              WHEN tasks.task_type = '3'
                THEN 'buddy'
              WHEN tasks.task_type = '4'
                THEN 'jira'
              WHEN tasks.task_type = '5'
                THEN workspaces.name
              WHEN tasks.task_type = '6'
                THEN custom_fields.name
              WHEN tasks.task_type = '7'
                THEN 'service_now'
              END AS calculated")
        .joins("
          LEFT OUTER JOIN users AS task_users ON task_users.id = tasks.owner_id
          LEFT OUTER JOIN workspaces ON tasks.workspace_id = workspaces.id
          LEFT OUTER JOIN custom_fields ON tasks.custom_field_id = custom_fields.id")
        .reorder("calculated asc")}
      elsif params[:sort_type] == 'assignee_z_a'
        filter {|relation| relation.select("
         tasks.*, CASE WHEN tasks.task_type = '0'
              THEN task_users.preferred_full_name
              WHEN tasks.task_type = '1'
                THEN 'hire'
              WHEN tasks.task_type = '2'
                THEN 'manager'
              WHEN tasks.task_type = '3'
                THEN 'buddy'
              WHEN tasks.task_type = '4'
                THEN 'jira'
              WHEN tasks.task_type = '5'
                THEN workspaces.name
              WHEN tasks.task_type = '6'
                THEN custom_fields.name
              WHEN tasks.task_type = '7'
                THEN 'service_now'
              END AS calculated")
        .joins("
          LEFT OUTER JOIN users AS task_users ON task_users.id = tasks.owner_id
          LEFT OUTER JOIN workspaces ON tasks.workspace_id = workspaces.id
          LEFT OUTER JOIN custom_fields ON tasks.custom_field_id = custom_fields.id")
        .reorder("calculated desc")}
      elsif params[:sort_type] == 'latest_due_date'
        filter {|relation| relation.reorder("tasks.deadline_in desc")}
      elsif params[:sort_type] == 'recent_due_date' 
        filter {|relation| relation.reorder("tasks.deadline_in asc")}
      end 
    else
      order_in = params[:sort_order]&.downcase == 'desc' ? 'desc' : 'asc'
      if params[:sort_column] == 'sanitized_name'
        filter {|relation| relation.reorder("tasks.sanitized_name #{order_in}")}
      elsif params[:sort_column] == 'assign_date'
        filter {|relation| relation.reorder("tasks.before_deadline_in #{order_in}").order("tasks.time_line #{order_in}")}
      elsif params[:sort_column] == 'due_date'
        if order_in == 'asc'
          filter {|relation| relation.reorder('tasks.deadline_in asc').order("tasks.task_schedule_options->>'due_date_relative_key' desc")}
        else
          filter {|relation| relation.reorder('tasks.deadline_in desc').order("tasks.task_schedule_options->>'due_date_relative_key' asc")}
        end
      elsif params[:sort_column] == 'assignee'
        filter {|relation| relation.select("
          tasks.*, CASE WHEN tasks.task_type = '0'
                THEN
                  CASE WHEN company.display_name_format = '0'
                    THEN
                      CASE WHEN COALESCE(task_users.preferred_name , '') = ''
                        THEN CONCAT(task_users.first_name, ' ', task_users.last_name)
                      ELSE
                        CONCAT(task_users.preferred_name, ' ', task_users.last_name)
                      END
                  WHEN company.display_name_format = '1'
                    THEN
                      CASE WHEN COALESCE(task_users.preferred_name , '') = ''
                        THEN task_users.first_name
                      ELSE
                        task_users.preferred_name
                      END
                  WHEN company.display_name_format = '2'
                    THEN CONCAT(task_users.first_name, ' ', task_users.last_name)
                  WHEN company.display_name_format = '3'
                    THEN
                      CASE WHEN COALESCE(task_users.preferred_name , '') = ''
                        THEN CONCAT(task_users.first_name, ' ', task_users.last_name)
                      ELSE
                        CONCAT(task_users.first_name, ' ', task_users.preferred_name, ' ', task_users.last_name)
                      END
                  WHEN company.display_name_format = '4'
                    THEN CONCAT(task_users.last_name, ' ', task_users.first_name)
                  END
               WHEN tasks.task_type = '1'
                 THEN 'Hire'
               WHEN tasks.task_type = '2'
                 THEN 'Manager'
               WHEN tasks.task_type = '3'
                 THEN 'Buddy'
               WHEN tasks.task_type = '4'
                 THEN 'Jira'
               WHEN tasks.task_type = '5'
                 THEN workspaces.name
               WHEN tasks.task_type = '6'
                 THEN custom_fields.name
               WHEN tasks.task_type = '7'
                 THEN 'ServiceNow'
               END AS calculated")
         .joins('
           LEFT OUTER JOIN companies AS company ON company.id = workstreams.company_id
           LEFT OUTER JOIN users AS task_users ON task_users.id = tasks.owner_id
           LEFT OUTER JOIN workspaces ON tasks.workspace_id = workspaces.id
           LEFT OUTER JOIN custom_fields ON tasks.custom_field_id = custom_fields.id')
         .reorder("calculated #{order_in}")}
      end
    end
  end

  def name_filter
    filter do |relation|
      pattern = "%#{params[:term].to_s.downcase}%"
      relation.where("tasks.name ILIKE ?", pattern)
    end if params[:term]
  end

  def overdue_in_year_range_filter
    if params[:overdue].present? && params[:users_params].present? && (user_params["max_year"].present? || user_params["min_year"].present?)
      min_year = user_params["min_year"].to_i if user_params["min_year"].present?
      max_year = user_params["max_year"].to_i if user_params["max_year"].present?
      filter do |relation|
        relation
          .joins(task_user_connections: :user)
          .where(task_user_connections: {state: 'in_progress'})
      end
      #individual cases
      filter {|relation| relation.where("users.start_date > ? AND task_user_connections.due_date < ?", min_year.years.ago.to_date, Date.today)} if !user_params["max_year"].present? && !user_params["combined_query"].present? && !user_params["retention"].present?#11
      filter {|relation| relation.where("users.start_date BETWEEN ? AND ? AND task_user_connections.due_date < ?", max_year.years.ago.to_date + 1.day, (max_year - 1).years.ago.to_date, Date.today)} if !user_params["min_year"].present? && !user_params["combined_query"].present? && !user_params["retention"].present? #12
      filter {|relation| relation.where("users.start_date < ? AND task_user_connections.due_date < ?", max_year.years.ago.to_date + 1.day, Date.today)} if !user_params["combined_query"].present? && user_params["retention"].present? #13

      #combined cases
      filter {|relation| relation.where("users.start_date > ? AND task_user_connections.due_date < ?", max_year.years.ago.to_date, Date.today)} if user_params["combined_query"].present? && !user_params["retention"].present? #11, 12
      filter {|relation| relation.where("((users.start_date BETWEEN ? AND ?) OR (users.start_date < ?)) AND task_user_connections.due_date < ?", min_year.years.ago.to_date + 1.day, (min_year - 1).years.ago.to_date, max_year.years.ago.to_date, Date.today)} if user_params["combined_query"].present? && user_params["retention"].present? && user_params["min_year"].present? #11, 13
      filter {|relation| relation.where("users.start_date < ? AND task_user_connections.due_date < ?", (max_year - 1).years.ago.to_date, Date.today)} if user_params["combined_query"].present? && user_params["retention"].present? && !user_params["min_year"].present? #12, 13

      filter do |relation|
        relation
          .group(:id)
          .reorder('count_all desc')
          .select('tasks.*, COUNT(*) AS count_all')
      end
    end
  end

  def company_filter
    filter do |relation|
      if ( user_params.present? &&
           user_params["dashboard_search"].present? &&
           user_params["sub_tab"].present? &&
           user_params["sub_tab"] == 'dashboard' &&
           params[:overdue].present?
         )
        relation.joins("INNER JOIN workstreams ON workstreams.id = tasks.workstream_id")
                .where("workstreams.company_id = ?", params[:company_id])
      else
        relation.joins(:workstream).where(workstreams: {company_id: params[:company_id]})
      end
    end if params[:company_id]
  end

  def superuser_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("users.super_user = 'false'")
    end if user_params.present? && user_params["dashboard_search"].present? && user_params["sub_tab"].present? && user_params["sub_tab"] == 'dashboard'
  end

  def workstream_filter
    filter do |relation|
      relation.joins(:workstream).where(workstreams: {id: params[:workstream_id]})
    end if params[:workstream_id]
  end

  def user_filter
    filter do |relation|
      relation.joins(:task_user_connections).where('user_id = ?', params[:user_id])
    end if params[:user_id]
  end

  def owner_filter
    filter do |relation|
      relation.joins(:task_user_connections).where('task_user_connections.owner_id = ?', params[:owner_id])
    end if params[:owner_id]
  end

  def tuc_state_filter
    filter { |relation|  relation.joins(:task_user_connections).where(task_user_connections: {state:  'in_progress'}).group(:id).reorder('count_all desc').select('tasks.*, COUNT(*) AS count_all') } if params[:open].present?  && params["users_params"] && user_params["tuc_state"]
  end

  def overdue_filter
    filter do |relation|
      relation
        .joins(:task_user_connections)
        .where("task_user_connections.state = 'in_progress' AND task_user_connections.due_date < ? ", Date.today)
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params[:overdue].present?
  end

  def recent_employees_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.state = 'active' AND users.current_stage NOT IN (:neglectStages)",
        neglectStages: [
          User.current_stages[:incomplete],
          User.current_stages[:departed],
          User.current_stages[:offboarding],
          User.current_stages[:last_week],
          User.current_stages[:last_month],
          User.current_stages[:registered]
        ]).group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["recent_employees"]
  end

  def stage_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.state = 'active' AND users.current_stage IN (?)", user_params["current_stage[]"])
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["current_stage[]"].present?
  end

  def team_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.state = 'active' AND users.team_id IN (?)", user_params["team_id[]"])
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["team_id[]"].present?
  end

  def location_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.state = 'active' AND users.location_id IN (?)", user_params["location_id[]"])
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["location_id[]"].present?
  end

  def pre_start_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:pre_start])
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["pre_start"]
  end

  def first_week_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:first_week])
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["first_week"]
  end

  def first_month_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:first_month])
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["first_month"]
  end

  def ramping_up_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.state = 'active' AND users.current_stage = ?", User.current_stages[:ramping_up])
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["ramping_up"]
  end

  def state_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.state = 'active' AND users.current_stage IN (?, ?)", User.current_stages[:invited], User.current_stages[:preboarding])
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["state[]"].present?
  end

  def all_departures_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.current_stage IN (?, ?, ?, ?)",
          User.current_stages[:offboarding],
          User.current_stages[:departed],
          User.current_stages[:last_month],
          User.current_stages[:last_week]
        )
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["all_departures"].present?
  end

  def current_stage_offboarded_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.current_stage = ?", User.current_stages[:departed])
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["current_stage_offboarded"].present?

  end

  def current_stage_offboarding_weekly_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND task_user_connections.state = 'in_progress' AND users.state = 'active' AND users.current_stage = ? ", User.current_stages[:last_week])
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["current_stage_offboarding_weekly"].present?
  end

  def current_stage_offboarding_monthly_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.state = 'active' AND users.current_stage = ? ", User.current_stages[:last_month])
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["current_stage_offboarding_monthly"].present?
  end

  def tuc_counts
    if params[:open].present?
      relation
        .joins(:task_user_connections)
        .where('task_user_connections.state = ?', 'in_progress')
        .group(:id)
        .reorder('count_all desc')
        .count(:all)
    elsif params[:overdue].present?
      relation
        .joins(:task_user_connections)
        .where("task_user_connections.state = 'in_progress' AND task_user_connections.due_date < ?", Date.today)
        .group(:id)
        .reorder('count_all desc')
        .count(:all)
    end
  end

  def active_employees_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where.not("users.current_stage IN (#{User.current_stages[:incomplete]}, #{User.current_stages[:departed]}, #{User.current_stages[:offboarding]}, #{User.current_stages[:last_month]}, #{User.current_stages[:last_week]})")
        .where("task_user_connections.state = 'in_progress' AND users.state = 'active'")
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params["users_params"] && user_params["active_employees"].present? && !user_params["query_year"].present?
  end

  def overdue_active_employees_filter
    filter do |relation|
      relation
        .joins(task_user_connections: :user)
        .where("task_user_connections.state = 'in_progress' AND users.state = 'active' AND task_user_connections.due_date < ? AND users.current_stage = ?", Date.today, User.current_stages[:registered])
        .group(:id)
        .reorder('count_all desc')
        .select('tasks.*, COUNT(*) AS count_all')
    end if params[:overdue].present?  && params["users_params"] && user_params["active_employees"].present? && !user_params["query_year"].present?
  end

  def searched_user_task_filter
    if params[:open].present? && params[:users_params].present? && user_params["term"].present?
      pattern = "#{user_params["term"].to_s.downcase}%"
      filter do |relation|
        relation
          .joins(task_user_connections: :user)
          .where(task_user_connections: {state: 'in_progress'})
          .where("lower(TRIM(first_name)) LIKE :pattern OR lower(TRIM(last_name)) LIKE :pattern OR lower(TRIM(preferred_name)) LIKE :pattern OR CONCAT(lower(TRIM(users.first_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern OR CONCAT(lower(TRIM(users.preferred_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern", pattern: pattern)
        end
    end
  end

  def overdue_searched_user_task_filter
    if params[:overdue].present? && params[:users_params].present? && user_params["term"].present?
      pattern = "#{user_params["term"].to_s.downcase}%"
      filter do |relation|
        relation
          .joins(task_user_connections: :user)
          .where(task_user_connections: {state: 'in_progress'})
          .where("lower(TRIM(first_name)) LIKE :pattern OR lower(TRIM(last_name)) LIKE :pattern OR lower(TRIM(preferred_name)) LIKE :pattern OR CONCAT(lower(TRIM(users.first_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern OR CONCAT(lower(TRIM(users.preferred_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern", pattern: pattern)
        end
    end
  end

  def user_params
    @user_params ||= JSON.parse(params["users_params"]) rescue nil
  end
end
