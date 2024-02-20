module CalendarBuilder
  class OffboardingDateCalendarFeedBuilder < CalendarFeedBuilder
    private

    attr_reader :calendar_feed

    def calendar_name
      I18n.t('calendar_feed.offboarding_feed.calendar_name', company_name: @calendar_feed.company.name)
    end

    def build_calendar_events
      users = @calendar_feed.company.users_without_super_user.where(current_stage: %i[offboarding last_month last_week departed])
                            .includes(:team, :location)
      events = users.map do |user|
        can_sync = user.termination_date.present? && user.user_is_ghost.blank?

        next unless can_sync

        {
          dtstart: user.termination_date,
          summary: event_summary(user),
          description: event_description(user)
        }
      end

      events.select(&:present?)
    end

    def event_summary(user)
      location_name = user.location_name || I18n.t('calendar_feed.offboarding_feed.no_location_name')
      title = user.title || I18n.t('calendar_feed.offboarding_feed.no_title')

      I18n.t('calendar_feed.offboarding_feed.summary',
             user_name: user.display_name, title: title, location_name: location_name)
    end

    def event_description(user)
      I18n.t('calendar_feed.offboarding_feed.description', display_name: user.display_name, team: team_name(user),
             location_name: location_name(user), manager_name: manager_name(user),
             termination_date: termination_date(user), last_day_worked: last_day_worked(user))
    end

    def location_name(user)
      user.location_name || I18n.t('calendar_feed.offboarding_feed.description_no_location_name')
    end

    def manager_name(user)
      user.manager&.display_name || I18n.t('calendar_feed.offboarding_feed.description_no_manager_name')
    end

    def termination_date(user)
      user.termination_date&.to_formatted_s(:long) || I18n.t('calendar_feed.offboarding_feed.termination_date_not_assigned')
    end

    def last_day_worked(user)
      user.last_day_worked&.to_formatted_s(:long) || I18n.t('calendar_feed.offboarding_feed.last_day_worked_not_assigned')
    end

    def team_name(user)
      user.team&.name || I18n.t('calendar_feed.offboarding_feed.no_team_assigned')
    end
  end
end
