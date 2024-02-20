module CalendarBuilder
  class Builder < ApplicationService
    def initialize(company, calendar_feed_id)
      super()
      @company = company
      @calendar_feed = CalendarFeed.allowed_calendar_feeds(@company, calendar_feed_id)
    end

    def call
      return unless calendar_feed

      feed_builder = fetch_feed_builder[calendar_feed.feed_type.to_sym]
      calendar_data = "CalendarBuilder::#{feed_builder}CalendarFeedBuilder".constantize.call(calendar_feed)

      create_calendar(calendar_data) if calendar_data[:calendar_events].present?
    end

    private

    attr_reader :calendar_feed, :company

    def fetch_feed_builder
      {
        overdue_activity: 'OverDueActivities',
        anniversary: 'Anniversary',
        birthday: 'Birthday',
        offboarding_date: 'OffboardingDate',
        start_date: 'StartDate',
        out_of_office: 'OutOfOffice',
        holiday: 'Holiday'
      }
    end

    def create_calendar(calendar_data)
      require 'icalendar'

      calendar = Icalendar::Calendar.new
      calendar.x_wr_calname = calendar_data[:calendar_name]

      calendar_data[:calendar_events].each do |calendar_event|
        event = Icalendar::Event.new
        event.dtstart = Icalendar::Values::Date.new(calendar_event[:dtstart])
        event.dtend = Icalendar::Values::Date.new(calendar_event[:dtend]) if calendar_event[:dtend]
        event.summary = calendar_event[:summary]
        event.description = calendar_event[:description]
        calendar.add_event(event)
      end

      calendar.to_ical
    end
  end
end
