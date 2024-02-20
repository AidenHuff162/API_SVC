module CalendarBuilder
  class BirthdayCalendarFeedBuilder < CalendarFeedBuilder
    def initialize(calendar_feed)
      super(calendar_feed)
      @birthday_field_id = fetch_birthday_field_id(calendar_feed.company)
    end

    private

    attr_reader :birthday_field_id

    def calendar_name
      I18n.t('calendar_feed.birthday_feed.calendar_name')
    end
    def fetch_birthday_field_id(company)
      company.custom_fields.find_by_name('birth')&.id
    end

    def build_calendar_events
      users = @calendar_feed.company.users_without_super_user.includes(:location, :manager).not_inactive_incomplete

      events = users.map do |user|
        # user should be regular company user and birthday exists
        dtstart = birthday_event_start_date(user) rescue nil
        can_sync = user.user_is_ghost.blank? && user.super_user.blank? && dtstart.present?

        next unless can_sync

        {
          dtstart: dtstart,
          summary: event_summary(user),
          description: event_description(user)
        }
      end

      events.select(&:present?)
    end

    def birthday_event_start_date(user)
      field_value = CustomFieldValue.find_by_user_and_field_id(user, @birthday_field_id)
      birth_date = field_value[0][:field_value].to_date

      if birth_date.present?
        Date.parse(I18n.t('calendar_feed.birthday_feed.birth_date',
                          date_today: Time.zone.today.year,
                          birth_date_month: birth_date.month,
                          birth_date_day: birth_date.day))

      end
    end

    def event_summary(user)
      if user.location_name
        I18n.t('calendar_feed.birthday_feed.summary_when_location',
               user_name: user.name_with_title, location_name: user.location_name)
      else
        I18n.t('calendar_feed.birthday_feed.no_location_summary', user_name: user.name_with_title)
      end
    end

    def event_description(user)
      if user.location_name && user.manager&.display_name
        I18n.t('calendar_feed.birthday_feed.description_manager_location',
               user_name: user.name_with_title, manager_name: user.manager&.display_name, location_name: user.location_name)
      else
        I18n.t('calendar_feed.birthday_feed.no_manager_location_description')
      end
    end
  end
end
