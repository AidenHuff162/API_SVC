class RemoveExistingCalendarEventsService
	include CalendarEventsCrudOperations

	def initialize params
    @company = Company.find_by_id(params)
  end

  def perform
    remove_calendar_events_for_company
  end

  def remove_calendar_events_for_company
    destroy_users_events
    destroy_holidays_events
  end

  def destroy_users_events
    @company.users.find_each do |user|
      remove_all_events_of_offboarded_user(user, true)
    end
  end

  def destroy_holidays_events
    @company.holidays.find_each do |holiday|    
      @company.calendar_events.where(eventable_type: 'Holiday', eventable_id: holiday.id).destroy_all
    end
  end  
end