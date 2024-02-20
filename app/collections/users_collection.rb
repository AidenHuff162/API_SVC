class UsersCollection < BaseCollection
  private

  def relation
    @relation ||= if params[:action] == 'get_role_users'
                    User.all.includes(:profile_image).order(first_name: :asc)
                  else
                    User.all.includes(:profile_image)
                  end
  end

  def ensure_filters
    company_filter
    superuser_filter
    job_title_filter
    email_filter
    activated_company_filter
    personal_email_filter
    email_or_personal_email_filter
    registered_filter
    offboarded_filter
    all_employees_filter
    onboarding_employees_filter
    offboarding_employees_filter
    incomplete_filter
    activated_filter
    manager_filter
    buddy_filter
    role_filter
    employee_type_filter
    team_filter
    people_filter
    location_filter
    point_in_time_filter
    point_in_time_registered_filter
    name_filter
    name_title_filter
    exclude_by_ids_filter
    just_before_date_filter
    recent_employees_filter
    current_stage_filter
    no_department_filter
    no_location_filter
    preferred_name_filter
    permission_term_filter
    creator_filter
    all_departures_filter
    current_stage_offboarded_filter
    current_stage_offboarding_weekly_filter
    current_stage_offboarding_monthly_filter
    current_stage_offboarding_monthly_weekly_filter
    state_filter
    pre_start_filter
    first_week_filter
    first_month_filter
    ramping_up_filter
    in_year_range_filter
    last_month_filter
    last_week_filter
    departed_filter
    custom_field_option_filter
    unassigned_custom_group_filter
    active_employees_filter
    hire_date_range_filter
    default_end_date_range_filter
    termination_date_range_filter
    sorting_filter
    user_role_filter
    user_role_id_filter
    not_offboarded_state_filter
    custom_group_users_filter
    organization_chart_users_filter
    email_should_be_active_filter
    activity_owner_filter
    workspace_page_filter
    offboarding_employees_search_filter
    pluck_job_titles_filter
    mention_filter
    id_filter
    exclude_user_role
    all_outstanding_tasks_count_filter
    total_overdue_activities_count_filter
    count_filter
    user_id_filter
    new_arrivals_filter
    transition_employees_filter
    working_employees_filter
    all_pto_policies_filter
    pto_policy_filter
    turnover_departed_users_filter
    custom_fields_filter
    exclude_users_filter
    manager_users_filter
    exclude_departed_filter
    integration_not_synced_filter
    permissions_filter
    multiple_custom_groups_filter
    multiple_custom_groups_employee_type_filter
    only_managers_filter
    current_user_not_super_admin_filter
    exclude_super_user_filter
    headcount_filters
    termination_type_filter
  end

  def user_role_filter
    filter { |relation| relation.where(user_role_id: nil) } if params[:user_role]
  end

  def user_id_filter
    filter {|relation| relation.where(id: params[:user_id]) } if params[:user_id]
  end

  def user_role_id_filter
    filter { |relation| relation.where(user_role_id: params[:user_role_id]) } if params[:user_role_id]
  end

  def count_filter
    filter { |relation| relation.count } if params[:count]
  end

  def superuser_filter
    unless params[:user_role_id] && UserRole.find(params[:user_role_id]).name == 'Ghost Admin'
      filter { |relation| relation.where(super_user: false) }
    end
  end

  def activated_company_filter
    filter { |relation| relation.joins(:company).where(companies: {deleted_at: nil}) }
  end

  def creator_filter
    filter { |relation| relation.where(created_by_id: params[:created_by_id], current_stage: User.current_stages[:incomplete]).order(updated_at: :desc)} if params[:created_by_id]
  end

  def email_filter
    filter { |relation| relation.where(email: params[:email]) } if params[:email]
  end

  def manager_filter
    if params[:team] && params[:manager_id]
      filter { |relation| relation.where(manager_id: params[:manager_id]) }
    elsif params[:manager_id]
      filter { |relation| relation.where(manager_id: params[:manager_id]) }
      if params[:offboarded]
        filter { |relation| relation.where(state: :inactive, current_stage: User.current_stages[:departed]) }
      else
        filter do |relation| 
          relation.where.not(state: :inactive, 
                             current_stage: [User.current_stages[:departed], User.current_stages[:incomplete]])
        end
      end
    end
  end

  def buddy_filter
    filter { |relation| relation.where(buddy_id: params[:buddy_id]) } if params[:buddy_id]
  end

  def company_filter
    filter { |relation| relation.where(company_id: params[:company_id]) } if params[:company_id]
  end

  def personal_email_filter
    filter { |relation| relation.where(personal_email: params[:personal_email]) } if params[:personal_email]
  end

  def job_title_filter
    filter { |relation| relation.where("title LIKE ?",'%' + "#{params[:job_title]}" + '%') } if params[:job_title]
  end

  def email_or_personal_email_filter
    filter do |relation|
      relation.where('email = :email OR personal_email = :email',
        email: params[:email_or_personal_email])
    end if params[:email_or_personal_email]
  end

  def registered_filter
    filter { |relation| relation.where(state: :active, current_stage: [3, 4, 5, 6, 11, 13, 14]) } if params[:registered] && !params[:point_in_time_date]
  end

  def offboarded_filter
    filter { |relation| relation.where(state: :inactive, current_stage: [7]) } if params[:offboarded]
  end

  def all_employees_filter
    filter { |relation| relation.where.not(current_stage: [0, 1, 2]) } if params[:all_employees]
  end

  def onboarding_employees_filter
    filter { |relation| relation.where(current_stage: [0, 1, 2, 3, 4, 5]) } if params[:onboarding_employees]
  end

  def offboarding_employees_filter
    filter { |relation| relation.where(current_stage: [6, 13, 14]) } if params[:offboarding_employees]
  end

  def incomplete_filter
    filter { |relation| relation.where(current_stage: User.current_stages[:incomplete]) } if params[:incomplete]
  end

  def activated_filter
    filter { |relation| relation.where(state: :active) } if params[:activated]
  end

  def role_filter
    filter { |relation| relation.where(role: params[:role]) } if params[:role]
  end

  def employee_type_filter
    if params[:company_id] && params[:employee_type] && params[:employee_type] != 'All Employee Status' && !params[:multiple_custom_groups]
      filter { |relation| relation.joins(:custom_field_values => [custom_field_option: :custom_field]).where("custom_fields.company_id = ? AND custom_fields.field_type = ? AND custom_field_options.option IN (?)", params[:company_id], 13, params[:employee_type]) }
    end
  end

  def team_filter
    filter { |relation| relation.where(team_id: params[:team_id]) } if params[:team_id]
  end

  def people_filter
    filter do |relation|
      relation.where("users.start_date <= ?", Date.today)
    end if params[:people]
  end

  def location_filter
    filter { |relation| relation.where(location_id: params[:location_id]) } if params[:location_id]
  end

  def point_in_time_filter
    filter { |relation| relation.where("start_date <= ? OR is_rehired = 'true'", params[:point_in_time_date]) } if params[:point_in_time_date]
  end


  def point_in_time_registered_filter
    filter { |relation| relation.where("(state = 'active' AND (current_stage IN (3, 4, 5, 6, 11, 13, 14) OR (is_rehired = 'true' AND current_stage IN (0, 1, 2))))  OR (state = 'inactive' AND termination_date IS NOT NULL AND termination_date >= ?)", params[:point_in_time_date]) } if params[:point_in_time_date] && params[:registered]
  end

  def recent_employees_filter
    filter do |relation|
      relation.where(
        '((outstanding_tasks_count > 0 OR (incomplete_paperwork_count + incomplete_upload_request_count) > 0 OR start_date > :ago) AND (current_stage NOT IN (:neglectStages)) AND (users.state = :activeState))',
        ago: Sapling::Application::ONBOARDING_DAYS_AGO,
        neglectStages: [
          User.current_stages[:incomplete],
          User.current_stages[:departed],
          User.current_stages[:offboarding],
          User.current_stages[:last_week],
          User.current_stages[:last_month],
          User.current_stages[:registered]
        ],
        activeState: 'active'
      ).order('start_date DESC','users.first_name')
    end if params[:recent_employees]
  end

  def working_employees_filter
    return unless params[:team]

    filter do |relation|
      relation.where('users.last_day_worked > ?
                     OR users.last_day_worked IS NULL',
                     DateTime.now)
              .where(state: 'active').where.not(current_stage: User.current_stages[:incomplete])
    end
  end

  def active_employees_filter
    filter { |relation| relation.where.not("users.current_stage IN (#{User.current_stages[:incomplete]}, #{User.current_stages[:departed]}, #{User.current_stages[:offboarding]}, #{User.current_stages[:last_month]}, #{User.current_stages[:last_week]})").where(state: 'active')} if params[:active_employees]
  end

  def hire_date_range_filter
    filter { |relation| relation.where('start_date BETWEEN ? AND ?', params[:hire_start_date_range],
                                       params[:hire_end_date_range]) 
           } if !params[:turnover_departed_users].present? && params[:hire_start_date_range] &&
                params[:hire_end_date_range] && !params[:default_report_type]
  end

  def default_end_date_range_filter
    if params[:selected_end_date] && params[:hire_start_date_range].blank? && params[:hire_end_date_range].present? && !params[:default_report_type]
      filter { |relation| relation.where("super_user = false AND (current_stage IN (3, 4, 5, 6, 7, 11, 13, 14)  OR (is_rehired = 'true' AND current_stage IN (0, 1, 2)))").where("termination_date IS NULL OR termination_date > ? OR EXTRACT(MONTH FROM termination_date) = EXTRACT(MONTH FROM start_date)", params[:hire_end_date_range]).where("start_date <= ?", params[:hire_end_date_range]) }
    end
  end
  def termination_date_range_filter
    filter { |relation| relation.where("termination_date >= ? AND termination_date <= ? ", params[:termination_date_filter][:start_date].to_date.beginning_of_day, params[:termination_date_filter][:end_date].to_date.end_of_day) } if params[:termination_date_filter]
  end

  def just_before_date_filter
    filter { |relation| relation.where('users.start_date <= ?', params[:just_before_date]).order(start_date: :desc) } if params[:just_before_date]
  end

  def name_filter
    filter do |relation|
      pattern = "#{params[:term].to_s.downcase}%"
      if params[:dashboard_search].present?
        relation.where("lower(TRIM(users.first_name)) LIKE :pattern OR lower(TRIM(users.last_name)) LIKE :pattern OR lower(TRIM(users.preferred_name)) LIKE :pattern OR CONCAT(lower(TRIM(users.first_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern OR CONCAT(lower(TRIM(users.preferred_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern", pattern: pattern).where("(users.state <> 'inactive' OR users.current_stage <> #{User.current_stages[:incomplete]}) OR ( (users.current_stage = ?) AND ( (users.termination_date > ?) OR (users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0)))",
          User.current_stages[:departed],
          15.days.ago)
      else
        relation.where("lower(TRIM(users.first_name)) LIKE :pattern OR lower(TRIM(users.last_name)) LIKE :pattern OR lower(TRIM(users.preferred_name)) LIKE :pattern OR CONCAT(lower(TRIM(users.first_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern OR CONCAT(lower(TRIM(users.preferred_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern", pattern: pattern).where("(users.state <> 'inactive' OR users.current_stage NOT IN (#{User.current_stages[:incomplete]}, #{User.current_stages[:departed]}) ) OR ( (users.current_stage = ?) AND ( (users.termination_date > ?) OR (users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0)))",
          User.current_stages[:departed],
          15.days.ago)
      end
    end if params[:term] && !params[:name_title_search]
  end

  def name_title_filter
    filter do |relation|
      pattern = "%#{params[:term].to_s.downcase}%"
      name_query = 'CONCAT(lower(TRIM(users.first_name)),\' \',lower(TRIM(users.last_name)),lower(TRIM(users.preferred_name))) LIKE ?'
      if params[:dashboard_search].present?
        relation.where("lower(TRIM(users.first_name)) LIKE :pattern OR lower(TRIM(users.last_name)) LIKE :pattern OR lower(TRIM(users.preferred_name)) LIKE :pattern OR CONCAT(lower(TRIM(users.first_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern OR CONCAT(lower(TRIM(users.preferred_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern", pattern: pattern).where.("(users.state <> 'inactive' OR users.current_stage <> #{User.current_stages[:incomplete]}) OR ( (users.current_stage = ?) AND ( (users.termination_date > ?) OR (users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0)))",
          User.current_stages[:departed],
          15.days.ago)
      elsif params[:offboarded]
        relation.where("lower(TRIM(users.first_name)) LIKE :pattern OR lower(TRIM(users.last_name)) LIKE :pattern OR lower(TRIM(users.preferred_name)) LIKE :pattern OR CONCAT(lower(TRIM(users.first_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern OR CONCAT(lower(TRIM(users.preferred_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern", pattern: pattern)
      else
        relation.where("lower(TRIM(users.first_name)) LIKE :pattern OR lower(TRIM(users.last_name)) LIKE :pattern OR lower(TRIM(users.preferred_name)) LIKE :pattern OR CONCAT(lower(TRIM(users.first_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern OR CONCAT(lower(TRIM(users.preferred_name)),\' \',lower(TRIM(users.last_name))) LIKE :pattern", pattern: pattern).where("(users.state <> 'inactive' OR users.current_stage NOT IN (#{User.current_stages[:incomplete]}, #{User.current_stages[:departed]}) ) OR ( (users.current_stage = ?) AND ( (users.termination_date > ?) OR (users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0)))",
          User.current_stages[:departed],
          15.days.ago)
      end
    end if params[:name_title_search] && params[:term]
  end

  def mention_filter
    filter do |relation|
      pattern = "#{params[:mention_query].to_s.downcase.gsub("(", "\\(")}%"

      relation.where("lower(TRIM(first_name)) SIMILAR TO ? OR lower(TRIM(last_name)) SIMILAR TO ? OR lower(TRIM(preferred_name)) SIMILAR TO ?", pattern, pattern, pattern).where.not("state = 'inactive' OR current_stage IN (#{User.current_stages[:incomplete]}, #{User.current_stages[:departed]})")
    end if params[:mention_query]
  end

  def permission_term_filter
    filter do |relation|
      pattern = "#{params[:permission_term].to_s.downcase}%"

      name_query = 'concat_ws(\' \', lower(users.first_name), lower(users.last_name), lower(users.preferred_name)) LIKE ?'

      relation.where("#{name_query}", pattern)
    end if params[:permission_term]
  end

  def no_department_filter
    filter { |relation| relation.where(team_id: nil).where.not(current_stage: User.current_stages[:departed]) } if params[:no_department]
  end

  def no_location_filter
    filter { |relation| relation.where(location_id: nil).where.not(current_stage: User.current_stages[:departed]) } if params[:no_location]
  end

  def exclude_by_ids_filter
    filter { |relation| relation.where.not(id: params[:exclude_ids]) } if params[:exclude_ids]
  end

  def exclude_departed_filter
    filter { |relation| relation.where.not(current_stage: User.current_stages[:departed]) } if params[:exclude_departed]
  end

  def current_stage_filter
    filter { |relation| relation.where(current_stage: params[:current_stage]) } if params[:current_stage]
  end

  def preferred_name_filter
    filter { |relation| relation.where(preferred_name: params[:preferred_name]) } if params[:preferred_name]
  end

  def current_stage_offboarded_filter
    filter { |relation| relation.where("(( current_stage IN (:offboarding_state) AND termination_date < :current_date) OR current_stage = :offboarded_state) AND (termination_date > :date_limit OR (outstanding_tasks_count > 0 OR (incomplete_paperwork_count + incomplete_upload_request_count) > 0))",
                                        offboarding_state: [
                                          User.current_stages[:last_week],
                                          User.current_stages[:last_month],
                                          User.current_stages[:offboarding]
                                        ],
                                        current_date:  Date.today,
                                        date_limit: 15.days.ago,
                                        offboarded_state: User.current_stages[:departed]
                                      )
     } if params[:current_stage_offboarded] && !params[:current_stage_offboarding_weekly] && !params[:current_stage_offboarding_monthly]

    filter { |relation| relation.where("((( current_stage IN (:offboarding_state) AND termination_date < :current_date) OR current_stage = :offboarded_state) AND (termination_date > :date_limit OR (outstanding_tasks_count > 0 OR (incomplete_paperwork_count + incomplete_upload_request_count) > 0))) OR (termination_date >= :current_date AND termination_date < :week_date)",
                                      offboarding_state: [
                                        User.current_stages[:last_week],
                                        User.current_stages[:last_month],
                                        User.current_stages[:offboarding]
                                      ],
                                      current_date:  Date.today,
                                      date_limit: 15.days.ago,
                                      week_date: (Date.today + 1.week),
                                      offboarded_state: User.current_stages[:departed]
                                    )
    } if params[:current_stage_offboarded] && params[:current_stage_offboarding_weekly] && !params[:current_stage_offboarding_monthly]

    filter { |relation| relation.where("((( current_stage IN (:offboarding_state) AND termination_date < :current_date) OR current_stage = :offboarded_state) AND (termination_date > :date_limit OR (outstanding_tasks_count > 0 OR (incomplete_paperwork_count + incomplete_upload_request_count) > 0))) OR (termination_date >= :week_date AND termination_date < :month_date)",
                                      offboarding_state: [
                                        User.current_stages[:last_week],
                                        User.current_stages[:last_month],
                                        User.current_stages[:offboarding]
                                      ],
                                      current_date:  Date.today,
                                      date_limit: 15.days.ago,
                                      offboarded_state: User.current_stages[:departed],
                                      month_date: (Date.today + 1.month),
                                      week_date: (Date.today + 1.week)
                                    )
    } if params[:current_stage_offboarded] && !params[:current_stage_offboarding_weekly] && params[:current_stage_offboarding_monthly]
  end

  def current_stage_offboarding_weekly_filter
    filter { |relation| relation.where("(current_stage iN (:offboarding_state)) AND termination_date >= :currentDate AND termination_date < :weekDate",
                                        offboarding_state: [
                                          User.current_stages[:last_week],
                                          User.current_stages[:last_month],
                                          User.current_stages[:offboarding]
                                        ],
                                        weekDate: (Date.today + 1.week),
                                        currentDate: Date.today
                                      )
    } if params[:current_stage_offboarding_weekly] && !params[:current_stage_offboarding_monthly] && !params[:current_stage_offboarded]
  end

  def current_stage_offboarding_monthly_filter
    filter { |relation| relation.where("(current_stage IN (:offboarding_state)) AND termination_date >= :weekDate AND termination_date < :monthDate",
                                        offboarding_state: [
                                          User.current_stages[:last_week],
                                          User.current_stages[:last_month],
                                          User.current_stages[:offboarding]
                                        ],
                                        monthDate: (Date.today + 1.month),
                                        weekDate: (Date.today + 1.week)
                                      )
    } if params[:current_stage_offboarding_monthly] && !params[:current_stage_offboarding_weekly] && !params[:current_stage_offboarded]
  end

  def current_stage_offboarding_monthly_weekly_filter
    filter { |relation| relation.where("(current_stage IN (:offboarding_state)) AND termination_date >= :currentDate AND termination_date < :monthDate",
                                        offboarding_state: [
                                          User.current_stages[:last_week],
                                          User.current_stages[:last_month],
                                          User.current_stages[:offboarding]
                                        ],
                                        monthDate: (Date.today + 1.month),
                                        currentDate: Date.today
                                      )
    } if params[:current_stage_offboarding_monthly] && params[:current_stage_offboarding_weekly] && !params[:current_stage_offboarded]
  end

  def state_filter
    filter { |relation| relation.where(state: params[:state]) } if params[:state]
  end

  def pre_start_filter
    filter { |relation| relation.where(current_stage: User.current_stages[:pre_start]) } if params[:pre_start]
  end

  def first_week_filter
    filter { |relation| relation.where(current_stage: User.current_stages[:first_week]) } if params[:first_week]
  end

  def first_month_filter
    filter { |relation| relation.where(current_stage: User.current_stages[:first_month]) } if params[:first_month]
  end

  def ramping_up_filter
    filter { |relation| relation.where(current_stage: User.current_stages[:ramping_up]) } if params[:ramping_up]
  end

  def in_year_range_filter
    if params[:max_year].present? || params[:min_year].present?
      min_year = params[:min_year].to_i if params[:min_year].present?
      max_year = params[:max_year].to_i if params[:max_year].present?

      #individual cases
      filter {|relation| relation.where("start_date > ?", min_year.years.ago.to_date)} if !params[:max_year].present? && !params[:combined_query].present? && !params[:retention].present?#11
      filter {|relation| relation.where("start_date BETWEEN ? AND ?", max_year.years.ago.to_date + 1.day, (max_year - 1).years.ago.to_date)} if !params[:min_year].present? && !params[:combined_query].present? && !params[:retention].present? #12
      filter {|relation| relation.where("start_date < ?", max_year.years.ago.to_date + 1.day)} if !params[:combined_query].present? && params[:retention].present? #13

      #combined cases
      filter {|relation| relation.where("start_date > ?", max_year.years.ago.to_date)} if params[:combined_query].present? && !params[:retention].present? #11, 12
      filter {|relation| relation.where("(start_date BETWEEN ? AND ?) OR (start_date < ?)", min_year.years.ago.to_date + 1.day, (min_year - 1).years.ago.to_date, max_year.years.ago.to_date)} if params[:combined_query].present? && params[:retention].present? && params[:min_year].present? #11, 13
      filter {|relation| relation.where("start_date < ?", (max_year - 1).years.ago.to_date)} if params[:combined_query].present? && params[:retention].present? && !params[:min_year].present? #12, 13
    end
  end

  def all_departures_filter
    filter { |relation| relation.where("((current_stage IN (?, ?, ?)) OR ((current_stage = ?) AND ((termination_date > ?) OR (outstanding_tasks_count > 0 OR (incomplete_paperwork_count + incomplete_upload_request_count) > 0))))",
      User.current_stages[:offboarding],
      User.current_stages[:last_month],
      User.current_stages[:last_week],
      User.current_stages[:departed],
      15.days.ago
      ) } if params[:all_departures]
  end

  def last_month_filter
    filter { |relation| relation.where(current_stage: User.current_stages[:last_month], state: 'active') } if params[:last_month]
  end

  def last_week_filter
    filter { |relation| relation.where(current_stage: User.current_stages[:last_week], state: 'active') } if params[:last_week]
  end

  def departed_filter
    filter { |relation| relation.where(current_stage: User.current_stages[:departed]) } if params[:departed]
  end

  def custom_field_option_filter
    return unless params[:custom_field_option_id]

    join_cfv = 'INNER JOIN custom_field_values ON custom_field_values.user_id = u.id AND custom_field_values.deleted_at IS NULL'
    custom_field_option_hash = Hash.new { |hash, key| hash[key] = [] }
    CustomFieldOption.where(id: params[:custom_field_option_id]).each { |cfo| custom_field_option_hash[cfo.custom_field_id] << cfo.id }
    option_filter_query = custom_field_option_hash.map do |_, option_ids|
      "(#{option_ids.map { |option_id| "(SELECT u.id FROM users AS u #{join_cfv} WHERE(custom_field_values.custom_field_option_id = #{option_id}))" }.join(' UNION ')})"
    end.join(' INTERSECT ')

    ids = ActiveRecord::Base.connection.exec_query("WITH users AS (#{option_filter_query}) SELECT users.id FROM users").rows.flatten
    filter { |relation| relation.where(id: ids) }
  end

  def unassigned_custom_group_filter
    if params[:unassigned_custom_group_id]
      user_ids = User.joins(:custom_field_values).where(custom_field_values: {custom_field_option_id: params[:unassigned_custom_group_id]}).pluck(:id)
      filter { |relation| relation.where.not(id: user_ids, current_stage: User.current_stages[:departed])} if user_ids
    end
  end

  def sorting_filter
    if params[:order_column] && params[:order_in]

      order_in = params[:order_in].downcase == 'asc' ? 'asc' : 'desc'

      if params[:prioritize_incomplete_form_by_manager].present?
        filter { |relation| relation.group('users.id').reorder(prioritize_incomplete_form_by_manager("users.first_name #{order_in}")) }

      elsif params[:order_column] == 'full_name'
        filter { |relation| relation.reorder("users.preferred_full_name #{order_in}") }

      elsif params[:order_column] == 'start_date'
        filter { |relation| relation.reorder("users.start_date #{order_in}") }
      elsif params[:order_column] == 'current_stage'
        filter { |relation| relation.reorder("users.current_stage #{order_in}, users.start_date #{order_in == 'asc' ? 'desc' : 'asc'}") }
      elsif params[:order_column] == 'title' || params[:order_column] == 'start_date' || params[:order_column] == 'first_name' || params[:order_column] == 'last_name'
        filter { |relation| relation.reorder("#{params[:order_column]} #{order_in}") }

      elsif params[:order_column] == 'preferred_full_name'
        if relation.length > 0 && relation.first.company.display_name_format == 4
          filter { |relation| relation.reorder("last_name #{order_in}") }
        elsif relation.length > 0 && (relation.first.company.display_name_format == 3 || relation.first.company.display_name_format == 2)
          filter { |relation| relation.reorder("first_name #{order_in}") }
        else
          filter { |relation| relation.reorder("preferred_full_name #{order_in}") }
        end

      elsif params[:order_column] == 'email'
        filter { |relation| relation.reorder("COALESCE(users.email, users.personal_email) #{order_in}") }

      elsif params[:order_column] == 'outstanding_owner_tasks_count'
        filter { |relation| relation.reorder("outstanding_owner_tasks_count #{order_in}") }

      elsif params[:order_column] == 'team_name'
        filter { |relation| relation.joins('LEFT OUTER JOIN "teams" ON "teams"."id" = "users"."team_id"').reorder("teams.name #{order_in}") }

      elsif params[:order_column] == 'location_name'
        filter { |relation| relation.joins('LEFT OUTER JOIN "locations" ON "locations"."id" = "users"."location_id"').reorder("locations.name #{order_in}") }

      elsif params[:order_column] == 'employee_type' && params[:employee_status_field_id].present?
        filter { |relation| relation.joins("LEFT OUTER JOIN custom_field_values ON custom_field_values.user_id = users.id AND custom_field_values.custom_field_id = #{params[:employee_status_field_id]} LEFT OUTER JOIN custom_field_options ON custom_field_options.id = custom_field_values.custom_field_option_id OR custom_field_values.custom_field_option_id = NULL").reorder("custom_field_options.option #{order_in}") }

      elsif params[:order_column] == 'manager_name' && relation.length > 0
        company = relation.take.company
        if company.display_name_format == 4
          order_column = "manager.last_name"
        elsif [2,3].include?(company.display_name_format)
          order_column = "manager.first_name"
        else
          order_column = "manager.preferred_full_name"
        end
        filter { |relation| relation.joins("LEFT OUTER JOIN users AS manager ON manager.id = users.manager_id").reorder("#{order_column} #{order_in}") }
      elsif params[:order_column] == 'termination_date'
        filter { |relation| relation.reorder("termination_date #{order_in}") }
      elsif params[:order_column] == 'last_day_worked'
        filter { |relation| relation.reorder("last_day_worked #{order_in}") }
      end
      filter { |relation| relation.order("preferred_full_name") }
    end
  end

  def prioritize_incomplete_form_by_manager(remaining_sort)
    [
      "COALESCE(SUM(CASE " \
      "WHEN (users.is_form_completed_by_manager = 1) " \
      "THEN " \
        "1 " \
      "ELSE " \
        "0 " \
      "END), 0) DESC",
      remaining_sort
    ]
  end

  def not_offboarded_state_filter
    filter { |relation| relation.where.not(current_stage: User.current_stages[:departed]) } if params[:not_offboarded]
  end

  def custom_group_users_filter
    filter { |relation| relation.where(id: params[:custom_group_users_ids]) } if params[:custom_group_users_ids]
  end

  def multiple_custom_groups_filter
    return unless params[:multiple_custom_groups]&.length&.positive?

    join_cfv = 'INNER JOIN custom_field_values ON custom_field_values.user_id = u.id AND custom_field_values.deleted_at IS NULL'
    group_filter_query = params[:multiple_custom_groups].map do |custom_group|
      next if (option_ids = custom_group[:custom_field_option_id].reject(&:blank?)).blank?

      "(SELECT u.id FROM users AS u #{join_cfv} WHERE(custom_field_values.custom_field_option_id IN (#{option_ids.join(',')})))"
    end.compact.join(' INTERSECT ')
    ids = ActiveRecord::Base.connection.exec_query(group_filter_query).rows.flatten
    filter { |relation| relation.where(id: ids) }
  end

  def organization_chart_users_filter
    filter { |relation| relation.where("users.manager_id IS NOT NULL or users.title = ?", 'CEO')
                                .where("users.current_stage NOT IN (?) ", [User.current_stages[:invited], User.current_stages[:preboarding], User.current_stages[:pre_start], User.current_stages[:departed], User.current_stages[:incomplete], User.current_stages[:no_activity]])
                                .where('last_day_worked >= ? OR last_day_worked IS NULL', Date.today).where(state: 'active').where('start_date <= ?', Date.today)
            } if params[:organization_chart_users]
  end

  def email_should_be_active_filter
    filter { |relation| relation.where.not(state: ['offboarded', 'new']) } if params[:check_user_state]
  end

  def workspace_page_filter
    if params[:workspace_page]
      workspace_member_ids = User.joins(:workspace_members).where("workspace_members.workspace_id = ?", params[:workspace_id]).pluck(:member_id)
      filter { |relation| relation.where.not(id: workspace_member_ids) }
    end
  end

  def activity_owner_filter
    if params[:activity_id]
      if params[:type] == 'task'
        if params[:overdue] == "overdue"
          ids = TaskUserConnection
                  .where(state: 'in_progress', task_id: params[:activity_id])
                  .where('task_user_connections.due_date < ?', Date.today)
                  .pluck(:owner_id)
                  .uniq
          filter { |relation| relation.where(id: ids)}
        else
          ids = TaskUserConnection
                  .where(state: 'in_progress', task_id: params[:activity_id])
                  .pluck(:owner_id)
                  .uniq
          filter { |relation| relation.where(id: ids)}
        end
      elsif params[:type] == 'document'
        ids = PaperworkRequest
                .where("(paperwork_requests.state= 'assigned' OR (paperwork_requests.state= 'signed' AND paperwork_requests.co_signer_id IS NOT NUll)) AND paperwork_requests.document_id=?", params[:activity_id] )
                .pluck(:user_id)
                .uniq
        filter { |relation| relation.where(id: ids)}
      elsif params[:type] == 'upload'
        ids = UserDocumentConnection
                .joins(:document_connection_relation)
                .where(state: 'request', document_connection_relation_id: params[:activity_id])
                .pluck(:user_id)
                .uniq
        filter { |relation| relation.where(id: ids)}
      end
    end
  end

  def offboarding_employees_search_filter
    filter do |relation|
      relation.where(
        '(current_stage NOT IN (:neglectStages) AND (users.state = :activeState))',
        neglectStages: [
          User.current_stages[:incomplete],
          User.current_stages[:departed],
          User.current_stages[:offboarding],
          User.current_stages[:last_week],
          User.current_stages[:last_month]
        ],
        activeState: 'active'
      )
    end if params[:offboarding_employees_search]
  end

  def pluck_job_titles_filter
    filter { |relation| relation.where.not(title: nil, current_stage: 8).pluck(:title).uniq } if params[:pluck_job_titles]
  end

  def id_filter
    filter { |relation| relation.where(id: params[:id]) } if params[:id]
  end

  def exclude_user_role
    filter { |relation| relation.where.not(user_role_id: params[:exclude_user_role_id].to_i) } if params[:exclude_user_role_id]
  end

  def all_outstanding_tasks_count_filter
    filter { |relation| relation.select("SUM(outstanding_tasks_count) AS outstanding_tasks_count") } if params[:all_outstanding_tasks_count]
  end

  def total_overdue_activities_count_filter
    filter do |relation|
      relation.joins("INNER JOIN task_user_connections ON task_user_connections.user_id = users.id")
              .joins("INNER JOIN users AS task_owner ON task_owner.id = task_user_connections.owner_id AND task_owner.current_stage NOT IN (#{User.current_stages[:incomplete]}, #{User.current_stages[:departed]}) AND task_owner.state <> 'inactive'")
              .where("task_user_connections.state = 'in_progress' AND due_date < ?", Date.today)
              .count
    end if params[:total_overdue_activities_count]
  end

  def new_arrivals_filter
    date = Date.today - 7.days
    filter { |relation| relation.where("start_date - ? <= ?", date, 7).where("start_date - ? >= 0", date).order('start_date desc').where("current_stage NOT IN (#{User.current_stages[:incomplete]})") } if params[:new_arrivals]
  end

  def transition_employees_filter
    filter do |relation|
      relation.where(
        '(outstanding_tasks_count > 0 OR (incomplete_paperwork_count + incomplete_upload_request_count) > 0)'
      ).order('start_date DESC','users.first_name')
    end if params[:transitions_dashboard]
  end

  def all_pto_policies_filter
      filter { |relation| relation.joins(:pto_policies) } if params[:pto_policy_id] && params[:pto_policy_id] == "all_pto_policies"
  end

  def pto_policy_filter
      filter { |relation| relation.joins(:pto_policies).where(pto_policies: {id: params[:pto_policy_id]}) } if params[:pto_policy_id] && params[:pto_policy_id] != "all_pto_policies"
  end

  def only_managers_filter
    filter { |relation| relation.select {|p| p.managed_user_ids.length > 0 }} if params[:only_managers]
  end

  def turnover_departed_users_filter
    filter do |relation|
      relation.where.not(current_stage: [0, 1, 2, 8, 12, 13, 14]).where("termination_date >= ? AND termination_date <= ?", params[:hire_start_date_range], params[:hire_end_date_range])
    end if params[:turnover_departed_users] && params[:hire_start_date_range].present? && params[:hire_end_date_range].present?
  end

  def custom_fields_filter
    filter { |relation| relation.joins(:custom_field_values).where(custom_field_values: {custom_field_option_id: params[:mcq_filters]})} if params[:mcq_filters].present?
  end

  def exclude_users_filter
    if params[:exclude_user_ids].present?
      ids = params[:exclude_user_ids].map{|a| a.to_i}
      filter { |relation| relation.where.not(id: ids)}
    end
  end

  def manager_users_filter
    if params[:manager_users_only]
      filter { |relation| relation.where(id: params[:manager_users])}
    end
  end

  def integration_not_synced_filter
    if %w[namely lessonly lattice].include?(params[:integration_name])
      filter { |relation| relation.unsynced_users(params[:integration_name]).where(state: :active) }
    elsif params[:integration_name] == 'workday'
      company = Company.find(params[:company_id])
      filter { |relation| relation.where(id: company.get_integration('workday').unsync_users.ids) }
    elsif params[:integration_name]
      filter { |relation| relation.unsynced_users(params[:integration_name]) }
    end
  end

  def permissions_filter
    if params[:lde_filter].present? && params[:current_user].present? && params[:current_user].role == 'admin'
      role = params[:current_user].user_role
      filter { |relation| relation.where(location_id: role.location_permission_level) } if role.location_permission_level && !role.location_permission_level.include?('all')
      filter { |relation| relation.where(team_id: role.team_permission_level) } if role.team_permission_level && !role.team_permission_level.include?('all')
      if role.status_permission_level && !role.status_permission_level.include?('all')
        custom_field_option_ids = CustomFieldOption.where(option: role.status_permission_level).pluck(:id)
        filter { |relation| relation.joins(:custom_field_values).where(custom_field_values: {custom_field_option_id: custom_field_option_ids}) }
      end
    end
  end

  def multiple_custom_groups_employee_type_filter
    return unless params[:employee_type]

    employee_type_filter_query = "custom_fields.company_id = #{params[:company_id]} AND custom_fields.field_type = 13 AND custom_field_options.option IN (?)"
    filter do |relation|
      relation.joins(custom_field_values: [custom_field_option: :custom_field])
              .where(employee_type_filter_query, params[:employee_type])
    end
  end

  def current_user_not_super_admin_filter
    if params[:current_user].present? && params[:current_user].role == 'account_owner'
      filter { |relation| relation.where.not(id: params[:current_user]) }
    end
  end

  def exclude_super_user_filter
    if params[:exclude_super_admins].present? && params[:current_user].user_role&.role_type.eql?('admin')
      filter { |relation| relation.joins(:user_role).where.not(user_roles: { role_type: UserRole.role_types[:super_admin] }) }
    end
  end

  def headcount_filters
    filter { |relation| relation.where("start_date <= ? AND (termination_date IS NULL OR termination_date > ?)",
                                       params[:hire_end_date_range], params[:hire_end_date_range])
                                 .where.not(current_stage: [0, 1, 2, 8, 12])
           } if params[:default_report_type] === 'default_user_report' && params[:hire_end_date_range]
  end

  def termination_type_filter
    filter { |relation| relation.where(termination_type: params[:termination_type_filter])} if params[:termination_type_filter]
  end
end 
