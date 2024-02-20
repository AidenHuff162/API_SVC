module CalendarBuilder
  class AnniversaryCalendarFeedBuilder < CalendarFeedBuilder
    private

    def calendar_name
      I18n.t('calendar_feed.anniversary_feed.calendar_name', company_name: @calendar_feed.company.name)
    end

    def build_calendar_events
      users = @calendar_feed.company.users_without_super_user.includes(:team, :location).not_inactive_incomplete

      events = users.map do |user|
        can_sync = user.user_is_ghost.blank? && user.super_user.blank?

        next unless can_sync

        anniversary_data = fetch_anniversary_data(user.start_date)
        events = []

        events.push({ dtstart: anniversary_data[:anniversary_date], summary: event_summary(user, anniversary_data[:anniversary_year]),
                      description: event_description(user) })

        events.push({ dtstart: anniversary_data[:anniversary_date_previous], summary: event_summary(user, anniversary_data[:anniversary_year_previous]),
                        description: event_description(user) }) if anniversary_data[:anniversary_date_previous].present?

        events
      end

      events.flatten.select(&:present?)
    end

    def fetch_anniversary_data(start_date)
      current_date = start_date > Time.zone.today ? start_date : Time.zone.today
      dates_diff_in_months = TimeDifference.between(current_date, start_date).in_months
      total_years = (dates_diff_in_months / 12).ceil

      if dates_diff_in_months < 6.0
        { anniversary_year: I18n.t('calendar_feed.anniversary_feed.year_1'), anniversary_date: (start_date + 6.months).strftime('%Y%m%d').to_s }
      else
        { anniversary_year_previous: I18n.t('calendar_feed.anniversary_feed.year_prev',
                                            total_years: (total_years - 1).humanize.titleize), anniversary_date_previous: (start_date + (total_years - 1).year).strftime('%Y%m%d').to_s,
          anniversary_year: I18n.t('calendar_feed.anniversary_feed.year_2', total_years: total_years.humanize.titleize),
          anniversary_date: (start_date + total_years.year).strftime('%Y%m%d').to_s }
      end
    end

    def event_summary(user, anniversary_year)
      if user.location_name
        I18n.t('calendar_feed.anniversary_feed.summary_when_location',
               user_name: user.name_with_title, anniversary_year: anniversary_year, location_name: user.location_name)
      else
        I18n.t('calendar_feed.anniversary_feed.no_location_summary',
               user_name: user.name_with_title, anniversary_year: anniversary_year)
      end
    end

    def event_description(user)
      if user.location_name && user.manager&.display_name
        I18n.t('calendar_feed.anniversary_feed.description_manager_location',
               user_name: user.display_name, manager_name: user.manager&.display_name,
               location_name: user.location_name)
      else
        I18n.t('calendar_feed.anniversary_feed.no_manager_location_description')
      end
    end
  end
end
