class CreateExistingCalendarEventsService
  include CalendarEventsCrudOperations

  def initialize params
    @company = Company.find_by_id(params)
  end

  def perform
    create_calendar_events_for_company
  end

  private

  def create_calendar_events_for_company
    if @company.enabled_calendar
      destroy_if_events_exist
      create_users_events
      create_holidays_events
    end
  end

  def destroy_if_events_exist
    if @company.calendar_events.count > 0
      @company.calendar_events.destroy_all
    end
  end

  def create_users_events
    @company.users.find_each do |user|
      create_calendar_event_for_individual_user(user) if user.active?
    end
  end

  def create_holidays_events
    @company.holidays.find_each do |holiday|
      setup_calendar_event(holiday, 'holiday', holiday.company)
    end
  end
end
