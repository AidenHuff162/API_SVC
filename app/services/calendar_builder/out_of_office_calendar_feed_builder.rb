module CalendarBuilder
  class OutOfOfficeCalendarFeedBuilder < CalendarFeedBuilder
    private

    attr_reader :calendar_feed

    def calendar_name
      I18n.t('calendar_feed.out_of_office_feed.calendar_name', company_name: @calendar_feed.company.name)
    end

    def build_calendar_events
      pto_requests = PtoRequest.where(user_id: @calendar_feed.company.users_without_super_user.ids)
                               .approved_requests.individual_requests.out_of_office_paid_time_off

      events = pto_requests.map do |pto|
        can_sync = pto.user.user_is_ghost.blank? && !pto.user.inactive?
        next unless can_sync

        event_policy_data = event_policy_data(pto)

        {
          dtstart: pto.begin_date,
          dtend: event_policy_data[:pto_end_date],
          summary: event_summary(pto, event_policy_data[:balance_hours]),
          description: event_description(pto)
        }
      end

      events.select(&:present?)
    end

    def event_policy_data(pto)
      balance_hours = pto.pto_policy.tracking_unit == 'hourly_policy' ? pto.balance_hours : (pto.balance_hours / pto.pto_policy.working_hours).round(1)
      partner_pto_requests = pto.partner_pto_requests.where('pto_requests.end_date > ?', Time.zone.today - 6.months).order(:id)

      partner_pto_requests.try(:find_each) do |partner_pto|
        balance_hours += partner_pto.pto_policy.tracking_unit == 'hourly_policy' ? partner_pto.balance_hours :
                           (partner_pto.balance_hours / partner_pto.pto_policy.working_hours).round(1)
      end

      pto_end_date = partner_pto_requests.present? ? partner_pto_requests.last.end_date : pto.end_date
      pto_end_date = (pto_end_date + 1.day) if pto.begin_date != pto_end_date

      { balance_hours: balance_hours.round(2), pto_end_date: pto_end_date }
    end

    def event_summary(pto, balance_hours)
      unit = pto.pto_policy.tracking_unit == 'hourly_policy' ? 'Hours' : 'Days'
      policy_name = pto.pto_policy&.display_detail ? pto.pto_policy.name : 'unavailable'
      
      I18n.t('calendar_feed.out_of_office_feed.summary',
             user_name: pto.user.name_with_title, policy_name: policy_name,
             balance_hours: balance_hours, unit: unit)
    end

    def event_description(pto)
      if pto.user.team&.name && pto.user&.location_name
        I18n.t('calendar_feed.out_of_office_feed.description_with_location',
               user_name: pto.user.display_name, team: pto.user.team&.name,
               location_name: pto.user&.location_name)
      else
        I18n.t('calendar_feed.out_of_office_feed.no_manager_location_description', user_name: pto.user.display_name)
      end
    end
  end
end
