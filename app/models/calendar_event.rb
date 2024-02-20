class CalendarEvent < ApplicationRecord
  acts_as_paranoid

  enum color: { '#F04514': 0, '#758ABF': 1, '#4E4DE3': 2, '#448A6B': 3, '#7D1C55': 4, '#B671BF': 5, '#18A7C8': 6, '#D28222': 7, '#A090E3': 8, '#B0E0E6': 9, '#ADD8E6': 10, '#ADFF2F': 11, '#D745DF': 12, '#542F9A': 13, '#E7805D': 14, '#C0606E': 15 , '#FFF':16, '#75000': 17 }
  enum event_type: { start_date: 0, last_day_worked: 1, task_due_date: 2, anniversary: 3, birthday: 4, time_off: 5, holiday: 6, time_off_vacation: 7, time_off_sick: 8, time_off_jury_duty: 9, time_off_parental_leave: 10, time_off_other: 11, time_off_training: 12, time_off_study: 13, time_off_work_from_home: 14, time_off_out_of_office: 15, unavailable: 16, time_off_vaccination: 17 }
  
  belongs_to :company
  belongs_to :eventable, polymorphic: true
  belongs_to :pto_request, -> { where(calendar_events: { eventable_type: 'PtoRequest' }) }, foreign_key: 'eventable_id'
  
  has_one :by_user, through: :pto_request, source: :user

  validates :event_type, uniqueness: { scope: %i[event_start_date event_end_date eventable_id eventable_type] }
  
  after_create :set_event_color
  after_create :set_event_visibility, if:  Proc.new { |cal_event| cal_event.eventable_type == 'PtoRequest' && cal_event.eventable.present? && cal_event.eventable.pto_policy.display_detail == false }
  after_restore :remove_duplicate_events
  
  scope :by_company, -> (company_id) { where('calendar_events.company_id = ?', company_id) }
  scope :pto_requests_by_users, -> (user_ids) { joins(:by_user).where(users: { id: user_ids }) }
  scope :all_by_month_range, -> (month_start, month_end, event_types) { includes(:eventable).where('(event_start_date BETWEEN ? AND ?) OR (event_end_date BETWEEN ? AND ?) OR ((event_start_date < ?) AND (event_end_date > ?))', month_start, month_end, month_start, month_end, month_start, month_end).where(event_type: event_types) }

  EVENT_CLR_MAPPING = {
    'anniversary' => 1,
    'birthday' => 2,
    'holiday' => 3,
    'time_off_vacation' => 4,
    'time_off_sick' => 5,
    'time_off_jury_duty' => 6,
    'time_off_parental_leave' => 7,
    'time_off_other' => 8,
    'time_off_training' => 12,
    'time_off_study' => 13,
    'time_off_work_from_home' => 14,
    'time_off_out_of_office' => 15,
    'unavailable' => 16,
    'time_off_vaccination' => 17
  }.freeze

  def set_event_visibility
    self.update(event_type: 16, color: 16)
  end

  def self.fetch_calendar_events(current_user, user_id, location_filters, department_filters, start_date = nil, end_date = nil, current_company, custom_group_filters, event_type_filters, managers_filters)
    return unless current_company
    user = current_company.users.find_by_id(user_id)
    return unless user
    task_events = []
    if current_user.user_role.permissions.present? && current_user.user_role.permissions['platform_visibility'].present?
      calendar_permission = get_permissions('calendar', current_user, user_id)
      task_permission = get_permissions('task', current_user, user_id)
    end
    event_filters = get_event_filters event_type_filters
    cal_events = get_calendar_events(start_date, end_date, current_user, event_filters)
    cal_events = cal_events.where.not(event_type: CalendarEvent.get_calendar_permissions(user.company))
    eventable_ids = get_eventable_ids(current_company, custom_group_filters, managers_filters)
    loc_and_team_sql = get_location_and_team_query(location_filters, department_filters)
    filtered_user_events = cal_events.joins("INNER JOIN users ON users.id = calendar_events.eventable_id AND calendar_events.eventable_type = 'User' AND users.company_id = #{current_user.company.id}").where(loc_and_team_sql).where('users.id IN (?)', eventable_ids)

    users_managed_by_admin = current_user.get_users_managed_by_admin if current_user.role == 'admin'
    filtered_task_events = cal_events.joins("INNER JOIN task_user_connections ON task_user_connections.id = calendar_events.eventable_id AND calendar_events.company_id = #{current_user.company.id} AND calendar_events.eventable_type = 'TaskUserConnection'").joins('INNER JOIN users ON users.id = task_user_connections.user_id').where(loc_and_team_sql).where('users.id IN (?)', eventable_ids)
    if event_filters.include? CalendarEvent.event_types[:task_due_date]
      task_events = task_calendar_events(current_user, user, filtered_task_events, calendar_permission, task_permission, users_managed_by_admin)
    end
    
    start_date_events = user_start_or_last_date_calendar_events(current_user, filtered_user_events, "start_date")
    last_date_events = user_start_or_last_date_calendar_events(current_user, filtered_user_events, "last_day_worked")
    pto_events = current_company.enabled_time_off ? fetch_pto_calendar_events(current_user, cal_events, loc_and_team_sql, event_filters, eventable_ids) : []
    holiday_events = current_company.show_holiday_events? ? holiday_calendar_events(cal_events, user, location_filters, department_filters, custom_group_filters) : []
    all_events = (start_date_events + last_date_events + task_events + pto_events + holiday_events).uniq
    return all_events if current_company.onboarding?
    
    user_events = user_calendar_events(current_user, user, current_user.company, filtered_user_events)
    (all_events + user_events).uniq
  end

  def year
    if event_type == 'anniversary' && eventable.present?
      TimeDifference.between(event_start_date, eventable.start_date).in_years.to_i.humanize.titleize
    end
  end

  private

  def self.get_location_and_team_query(location_filters, department_filters)
    sql = ''
    if location_filters.present?
      sql += "users.location_id IN (#{location_filters.join(',')})"
    end
    if department_filters.present?
      sql += sql != '' ? " AND users.team_id IN (#{department_filters.join(',')})" : "users.team_id IN (#{department_filters.join(',')})"
    end
    sql
  end

  def self.get_eventable_ids(current_company, custom_group_filters, managers_filters)
    users = current_company.users.where(super_user: false)
    filters_users_ids = []
    is_manager_empty = managers_filters.empty?
    is_custom_empty = custom_group_filters.empty?
    if is_custom_empty && is_manager_empty
      filters_users_ids = users.pluck(:id)
    end

    unless is_manager_empty
      filters_users_ids = users.where(manager_id: managers_filters).pluck(:id)
      filters_users_ids += managers_filters
    end

    unless is_custom_empty
      filters_users_ids += users.joins(:custom_field_values).where(custom_field_values: { custom_field_option_id: custom_group_filters }).pluck(:id)
    end

    filters_users_ids
  end

  def remove_duplicate_events
    company = self.company
    if company
      latest_calendar_event = company.calendar_events.where(event_start_date: event_start_date, event_type: CalendarEvent.event_types[event_type]).order('id desc').first
      if latest_calendar_event.present?
        company.calendar_events.where(event_start_date: event_start_date, event_type: CalendarEvent.event_types[event_type]).where.not(id: latest_calendar_event.id).destroy_all
      end
    end
  end

  def self.get_calendar_permissions(company)
    company.calendar_permissions.select { |_key, value| !value }.keys.map { |key| CalendarEvent.event_types[key] }
  end

  def set_event_color
    if %w[start_date last_day_worked task_due_date].include? event_type
      clr = 0
    else
      clr = EVENT_CLR_MAPPING[event_type] || 0
    end
    update_columns(color: clr)
  end

  def self.fetch_pto_calendar_events(current_user, cal_events, loc_and_team_sql, event_types, eventable_ids)
    pto_events = []
    unless ((7..17).to_a & event_types).empty?
      pto_events = pto_calendar_events(current_user, cal_events, loc_and_team_sql, eventable_ids)
    end
    pto_events
  end

  def self.pto_calendar_events(current_user, calendar_events, loc_and_team_sql, eventable_ids)
    user_ids = if !current_user.company.calendar_permissions['time_off'] && current_user.user_role.employee?
                 [current_user.id]
               else
                 eventable_ids
               end
    events = calendar_events.pto_requests_by_users(user_ids).joins(pto_request: :pto_policy).joins(pto_request: :user).where('pto_policies.is_enabled = true').where(loc_and_team_sql)
    
    events.present? ? events.distinct.to_a : []
  end

  def self.holiday_calendar_events(calendar_events, user, location_filters, department_filters, custom_group_filters)
    dept_filter = department_filters.map(&:to_s)
    loc_filter = location_filters.map(&:to_s)
    status_filter = user.company.employment_field.custom_field_options.where(id: custom_group_filters).pluck(:option)
    dept_filter.push('all')
    loc_filter.push('all')
    status_filter.push('all')

    holiday_events = calendar_events.joins("INNER JOIN holidays ON calendar_events.eventable_id = holidays.id AND calendar_events.eventable_type = 'Holiday'")
    unless location_filters.empty?
      holiday_events = holiday_events.where('ARRAY[?]::varchar[] && holidays.location_permission_level', loc_filter)
    end
    unless department_filters.empty?
      holiday_events = holiday_events.where('ARRAY[?]::varchar[] && holidays.team_permission_level', dept_filter)
    end
    unless custom_group_filters.empty?
      holiday_events = holiday_events.where('ARRAY[?]::varchar[] && holidays.status_permission_level', status_filter)
    end

    holiday_events.present? ? holiday_events.distinct.to_a : []
  end

  def self.get_calendar_events(start_date, end_date, _current_user, event_filters)
    if start_date.present? && end_date.present?
      cal_events = all_by_month_range(start_date.to_date, end_date.to_date, event_filters)
    else
      cal_events = all_by_month_range(Time.now.beginning_of_month, Time.now.end_of_month, event_filters)
    end
  end

  def self.get_event_filters(event_type_filters)
    event_types = event_type_filters.present? ? event_type_filters : CalendarEvent.event_types.values
  end

  def self.user_calendar_events(current_user, user, company, calendar_events)
    user_ids = company.users.where(state: 'active').ids
    events = calendar_events.where('eventable_type = ? AND eventable_id IN (?)', 'User', user_ids).where(event_type: [CalendarEvent.event_types['birthday'], CalendarEvent.event_types['anniversary']])

    events.present? ? events.uniq.to_a : []
  end

  def self.user_start_or_last_date_calendar_events(current_user, calendar_events, event_type)
    if current_user.employee?
      if current_user.user_role.role_type == 'manager'
        user_ids = current_user.user_role.direct_and_indirect? ? current_user.indirect_reports_ids : current_user.managed_users.pluck(:id)
        user_ids.push(current_user.id)
      else
        user_ids = [current_user.id]
      end
    else
      user_ids = current_user.company.users.ids
    end
    events = calendar_events.where('eventable_type = ? AND eventable_id IN (?)', 'User', user_ids).where(event_type: event_type)

    events.present? ? events.uniq.to_a : []
  end

  def self.task_calendar_events(current_user, user, calendar_events, calendar_permission, task_permission, users_managed_by_admin)
    events = []
    now = Time.now
    is_current_user = current_user.id == user.id
    is_account_owner = current_user.role == 'account_owner'
    has_permission = calendar_permission != 'no_access' && task_permission != 'no_access'

    if is_current_user && (is_account_owner || has_permission)
      events = calendar_events.select {|event| event.eventable_type ==  'TaskUserConnection' and event.eventable.present? and event.eventable.task.present? and event_workspace?(event, current_user, event.eventable.owner_id) and event.eventable.state == 'in_progress' and (event.eventable.before_due_date.blank? or (event.eventable.before_due_date.present? and event.eventable.before_due_date < now))}
    elsif !is_current_user && has_permission && (is_account_owner || (current_user.role == 'employee' && current_user.managed_users.pluck(:id).include?(user.id) || current_user.role == 'admin' && users_managed_by_admin.present? && users_managed_by_admin.include?(user.id))) # Manager or admin
      events = calendar_events.select {|event| event.eventable_type ==  'TaskUserConnection' and event.eventable.present? and event.eventable.task.present? and event_workspace?(event, user, event.eventable.user_id) and event.eventable.state == 'in_progress' and (event.eventable.before_due_date.blank? or (event.eventable.before_due_date.present? and event.eventable.before_due_date < now))}
    end
    events
  end

  def self.event_workspace?(event, user, event_user_id)
    if event.eventable.workspace_id
      !!event.eventable.task&.workspace&.workspace_members&.find_by(member_id: user.id)
    else
      event_user_id == user.id
    end
  end

  def self.get_permissions(tab, current_user, user_id)
    visibility = current_user.id == user_id && %w[manager admin].include?(current_user.user_role.role_type) ? 'own_platform_visibility' : 'platform_visibility'
    current_user.user_role.permissions[visibility][tab]
  end
end
