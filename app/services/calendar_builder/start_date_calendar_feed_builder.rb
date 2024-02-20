module CalendarBuilder
  class StartDateCalendarFeedBuilder < CalendarFeedBuilder
    private

    attr_reader :calendar_feed

    def calendar_name
      I18n.t('calendar_feed.start_date_feed.calendar_name', company_name: @calendar_feed.company.name)
    end

    def build_calendar_events
      users = @calendar_feed.company.users_without_super_user.includes(:location, :manager).not_inactive_incomplete

      events = users.map do |user|
        # user should be regular company user and in on-boarding state
        new_on_boarder = user.onboarding? && user.user_is_ghost.blank? && user.super_user.blank?

        next unless new_on_boarder

        {
          dtstart: user.start_date,
          summary: event_summary(user),
          description: event_description(user)
        }
      end

      events.select(&:present?)
    end

    def event_summary(user)
      I18n.t('calendar_feed.start_date_feed.summary', user_name: user.name_with_title)
    end

    def event_description(user)
      if user.location_name && user.manager&.display_name
        I18n.t('calendar_feed.start_date_feed.description_with_location_manager',
               user_name: user.display_name, location_name: user.location_name,
               manager_name: user.manager&.display_name)
      else
        I18n.t('calendar_feed.start_date_feed.no_manager_location_description')
      end
    end
  end
end
