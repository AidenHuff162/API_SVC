module CalendarBuilder
  class CalendarFeedBuilder < ApplicationService

    def initialize(calendar_feed)
      @calendar_feed = calendar_feed
    end

    def call
      { calendar_name: calendar_name, calendar_events: build_calendar_events }
    end

    private

    attr_reader :calendar_feed
  end
end
