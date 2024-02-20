module CalendarBuilder
  class OverDueActivitiesCalendarFeedBuilder < CalendarFeedBuilder
    private

    attr_reader :calendar_feed

    def calendar_name
      I18n.t('calendar_feed.over_due_activity_feed.calendar_name')
    end
    def build_calendar_events
      task_user_connections = TaskUserConnection.where(owner_id: @calendar_feed.user_id, state: 'in_progress').includes(:user, user: [:location])

      events = task_user_connections.map do |task_user_connection|
        can_sync = task_user_connection.user.user_is_ghost.blank? && task_user_connection.user.super_user.blank?
        next unless can_sync

        {
          dtstart: task_user_connection.due_date,
          summary: event_summary(task_user_connection),
          description: event_description(task_user_connection)
        }
      end

      events.select(&:present?)
    end

    def event_summary(task_user_connection)
      location_name = task_user_connection.user.location_name || I18n.t('calendar_feed.over_due_activity_feed.no_location_assigned')
      title = task_user_connection.user.title || I18n.t('calendar_feed.over_due_activity_feed.no_title')
      activity_name = fetch_activity_data(task_user_connection)[:name]

      I18n.t('calendar_feed.over_due_activity_feed.summary',
             activity_name: activity_name, user_name: task_user_connection.user.display_name,
             title: title, location_name: location_name)
    end

    def event_description(task_user_connection)
      fetch_activity_data(task_user_connection)[:description]
    end

    def fetch_text_from_html(string)
      Nokogiri::HTML(string).xpath('//*[p]').first.content rescue ' '
    end

    def fetch_activity_data(task_user_connection)
      user = task_user_connection.user
      task_name = ReplaceTokensService.new.replace_task_tokens(task_user_connection.task.name, user)
      task_description = ReplaceTokensService.new.replace_task_tokens(task_user_connection.task.description, user)

      activity_name = fetch_text_from_html(task_name) || I18n.t('calendar_feed.over_due_activity_feed.no_activity_name')
      activity_description = fetch_text_from_html(task_description) || I18n.t('calendar_feed.over_due_activity_feed.no_description')

      {
        name: activity_name,
        description: activity_description
      }
    end
  end
end
