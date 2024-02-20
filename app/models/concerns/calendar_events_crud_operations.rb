module CalendarEventsCrudOperations
  extend ActiveSupport::Concern

  USER_EVENTS = ['start_date', 'last_day_worked', 'anniversary', 'birthday']

  def setup_calendar_event object, event_type, company = nil, start_date = nil, end_date = nil
    return if !can_manage_calendar_event(company)  || object_is_ghost(object)
    if USER_EVENTS.include? event_type
      create_users_calendar_event(object, event_type, start_date, end_date) if object.active?
    elsif object.instance_of? TaskUserConnection
      create_task_calendar_event(object, event_type) if object.user.active?
    elsif object.instance_of? PtoRequest
      create_pto_calendar_event(object, event_type) if object.user.active?
    elsif object.instance_of? Holiday
      create_holiday_calendar_event(object, event_type)
    end
  end

  def update_holiday_calendar_event object
    calendar_event = object.calendar_event
    calendar_event.update(
      event_start_date: object.begin_date,
      event_end_date: object.end_date,
    )  if calendar_event
  end

  def update_user_event_date_range object, changed_attributes
    return if !can_manage_calendar_event(object.company) || object_is_ghost(object)
    changed_attributes.each do |attribute|
      update_event_date_range_for_user_object(object, attribute)
    end
  end

  def update_objects_date_range object, event_type, changed_attribute
    return if !can_manage_calendar_event(object&.user&.company) || object_is_ghost(object)
    calendar_event = object.calendar_events.find_by_event_type(CalendarEvent.event_types[event_type])
    calendar_event.update(event_start_date: object[changed_attribute], event_end_date: object[changed_attribute]) if calendar_event.present?
  end

  def remove_all_events_of_offboarded_user object, is_disabled_company_wide = false
    return unless can_manage_calendar_event(object.company) || is_disabled_company_wide
    task_ids = object.task_user_connections.ids
    object.calendar_events.destroy_all
    if object.company
      object.company.calendar_events.where(eventable_id: object.pto_requests.ids, eventable_type: 'PtoRequest').destroy_all if object.pto_requests.present?
      object.company.calendar_events.where(eventable_id: task_ids, eventable_type: 'TaskUserConnection').destroy_all if task_ids.present?
    end
  end

  def create_calendar_event_for_individual_user user
    return if object_is_ghost(user)
    create_birthday_event(user)
    create_anniversaries_events(user)
    create_task_events(user)
    create_onboarding_events(user)
    create_offboarding_events(user)
    create_all_pto_calendar_events_by_user(user)
  end

  private

  def can_manage_calendar_event company
    if (company.present? && company.enabled_calendar) || Rails.env.test?
      return true
    else
      false
    end
  end

  def create_users_calendar_event object, event_type, start_date = nil, end_date = nil
    if event_type == 'anniversary'
      object.create_default_anniversaries
    else
      if event_type == 'birthday'
        object.calendar_events.create(event_type: event_type, event_start_date: start_date, event_end_date: end_date, company_id: object.company_id)
      else
        event_date_range = get_users_event_date_range(object, event_type)
        object.calendar_events.create(event_type: event_type, event_start_date: event_date_range['start_date'], event_end_date: event_date_range['end_date'], company_id: object.company_id)
      end
    end
  end

  def create_task_calendar_event object, event_type
    return unless object.user.active? && object.task.present?
    task = object.task
    object.calendar_events.create(event_type: event_type, event_start_date: object.due_date, event_end_date: object.due_date, company_id: object.user.company_id) if task.present?
  end

  def create_pto_calendar_event object, event_type
    return unless object.user.active?
    user = object.user
    object.create_calendar_event(event_type: event_type, event_start_date: object.begin_date, event_end_date: object.get_end_date, company_id: user.company_id)
  end

  def create_holiday_calendar_event object, event_type
    object.end_date = object.begin_date if !object.multiple_dates
    object.create_calendar_event(event_type: event_type, event_start_date: object.begin_date, event_end_date: object.end_date, company_id: object.company_id)
  end

  def update_event_date_range_for_user_object object, attribute
    event = object.calendar_events.find_by_event_type(CalendarEvent.event_types[attribute])
    event.update(event_start_date: object[attribute], event_end_date: object[attribute]) rescue nil
  end

  def get_users_event_date_range object, event_type
    date_range_object = {}
    if event_type == 'last_day_worked'
      date_range_object['start_date'] = object.last_day_worked
      date_range_object['end_date'] = object.last_day_worked
    elsif event_type == 'start_date'
      date_range_object['start_date'] = object.start_date
      date_range_object['end_date'] = object.start_date
    end
    date_range_object
  end

  def create_all_pto_calendar_events_by_user user
    company = user.company
    user.pto_requests.where(status: PtoRequest.statuses[:approved]).find_each do |pto|
      pto_policy = 'time_off_' + pto.pto_policy.policy_type
      setup_calendar_event(pto, pto_policy, company, pto.begin_date, pto.end_date)
    end
  end

  def create_birthday_event user
    cf = user.company.custom_fields.find_by_name('Date of Birth') || cf = user.company.custom_fields.find_by_name('Birth Date') rescue nil
    cfv = user.custom_field_values.where(custom_field_id: cf.id).take if cf.present?
    user.create_date_of_birth_calendar_event(cfv.value_text) if cfv.present? && cfv.value_text.present?
  end

  def create_anniversaries_events user
    user.create_default_anniversaries
  end

  def create_task_events user
    tasks = user.task_user_connections.where(state: 'in_progress')
    tasks.each do |task|
      setup_calendar_event(task, 'task_due_date', user.company)
    end
  end

  def create_onboarding_events user
    setup_calendar_event(user, 'start_date', user.company)
  end

  def create_offboarding_events user
    if user.termination_date and user.last_day_worked.present?
      setup_calendar_event(user, 'last_day_worked', user.company)
    end
  end

  def object_is_ghost object
    if object.instance_of? User
      return object.user_is_ghost || object.super_user?
    elsif (object.instance_of? TaskUserConnection) || (object.instance_of? PtoRequest)
      return object.user.user_is_ghost
    elsif object.instance_of? Holiday
      return false
    end
  end

end
