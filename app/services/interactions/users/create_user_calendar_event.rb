module Interactions
  module Users
    class CreateUserCalendarEvent

      def perform
        companies_ids = Company.where(enabled_calendar: true).pluck(:id)
        users = User.where(company_id: companies_ids).where(state: 'active').where("current_stage NOT IN (#{User.current_stages[:last_week]}, #{User.current_stages[:last_month]}, #{User.current_stages[:offboarding]})").where("termination_date IS NULL").where("extract(month  from start_date) = ?", Date.today.month).where("extract(day  from start_date) = ?", Date.today.day).includes(:calendar_events)
        users.each do |user|
          # renew_anniversary_pto_policies(user)
          next if user.user_is_ghost
          last_anniversary = user.calendar_events.where(event_type: CalendarEvent.event_types["anniversary"]).order(event_start_date: :desc).take
          if last_anniversary.present?
            next_year = last_anniversary.event_start_date + 1.year
            years_diff = TimeDifference.between(user.start_date, next_year).in_years.to_i
            user.create_calendar_events_by years_diff
          end
        end
        users_calendar_events_with_current_date = CalendarEvent.where(company_id: companies_ids).where(event_type: CalendarEvent.event_types[:birthday]).where(event_start_date: Date.today).includes(:eventable)
        users_calendar_events_with_current_date.each do |calendar_event|
          user = calendar_event.eventable
          next if user.user_is_ghost
          if user && user.active?
            last_birthday_event = user.calendar_events.where(event_type: CalendarEvent.event_types[:birthday]).order(event_start_date: :desc).take
            event_date = last_birthday_event.event_start_date + 1.year
            user.calendar_events.create(event_type: CalendarEvent.event_types[:birthday], event_start_date: event_date, event_end_date: event_date, company_id: user.company_id)
          end
        end
      end

      private
      # Renewing pto policies which will renew on user's anniversary
      def renew_anniversary_pto_policies user
        policies_accrued_in_start = user.assigned_pto_policies.joins(:pto_policy).where("pto_policies.accrual_renewal_time = ? and pto_policies.allocate_accruals_at = ?", 0, 0)
        policies_accrued_in_end = user.assigned_pto_policies.joins(:pto_policy).where("pto_policies.accrual_renewal_time = ? and pto_policies.allocate_accruals_at = ?", 0, 1)
        if policies_accrued_in_start.size > 0
          Pto::ManagePtoBalances.new(0, user.company).annual_renewal_of_pto_policies(policies_accrued_in_start)
        end
        if policies_accrued_in_end > 0
          Pto::ManagePtoBalances.new(1, user.company).annual_renewal_of_pto_policies(policies_accrued_in_end)
        end
      end
    end
  end
end
