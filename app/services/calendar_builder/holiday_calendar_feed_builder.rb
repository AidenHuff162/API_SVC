module CalendarBuilder
  class HolidayCalendarFeedBuilder < CalendarFeedBuilder

    def initialize(calendar_feed)
      super(calendar_feed)
      @company = calendar_feed.company
    end

    private

    attr_reader :calendar_feed, :company

    def calendar_name
      I18n.t('calendar_feed.holiday_feed.calendar_name', company_name: company.name)
    end

    def build_calendar_events
      holiday_events = Holiday.where(company_id: company.id)

      events = holiday_events.map do |holiday|
        {
          dtstart: holiday.begin_date,
          dtend: holiday.end_date,
          summary: event_summary(holiday),
          description: event_description(holiday)
        }
      end
    end

    def event_summary(holiday)
      I18n.t('calendar_feed.holiday_feed.summary', company_name: company.name, holiday_name: holiday.name)
    end

    def event_description(holiday)
        I18n.t('calendar_feed.holiday_feed.description', company_name: company.name, holiday_name: holiday.name)
    end
  end
end
