module Pto
  class GetReturnDayOfUser

    def perform pto, is_digest = false
      pto_policy = pto.pto_policy
      @company = pto_policy.company
      return pto.end_date if pto.partial_day_included && pto.balance_hours < pto_policy.working_hours
      find_next_working_day pto, pto_policy, is_digest
    end

    def find_next_working_day pto, pto_policy, is_digest
      return find_next_working_day_for_digest(pto, pto_policy) if is_digest
      date = pto.end_date + 1.day
      date_limit = @company.time.to_date + 14.days
      return true if date > date_limit
      company_holidays = @company.get_holidays_between_dates @company.time.to_date, (@company.time.to_date + 14.days), pto.user
      # checking from supposed first day after time off to the date before fortnite
      (date..(date_limit)).to_a.try(:each) do |range_date|
        # check if the current range_date is a working day in the pto policy
        working_day = is_working_day range_date, pto_policy, company_holidays
        # check if there are any approved pto request for the user in the current range_date
        pto_requests = pto.user.pto_requests.approved_requests_in_range(range_date)
        # if it is a working day and there are no other approved request we will return the range_date
        # as the date when the user returns to work
        return range_date if working_day && pto_requests.size == 0
        return Pto::GetReturnDayOfUser.new.perform(pto_requests.first) if pto_requests.size > 0
      end
      return nil
    end

    def find_next_working_day_for_digest pto, pto_policy
      date = pto.end_date + 1.day
      company_holidays = @company.get_holidays_between_dates @company.time.to_date, (date + 14.days), pto.user
      return date if company_holidays.empty?
      (date..(date + 14.days)).to_a.try(:each) do |range_date|
        working_day = is_working_day range_date, pto_policy, company_holidays
        pto_requests = pto.user.pto_requests.approved_requests_in_range(range_date)
        return range_date  if working_day && pto_requests.size == 0
        return Pto::GetReturnDayOfUser.new.perform(pto_requests.first, true) if pto_requests.size > 0
      end
      return nil
    end

    def is_working_day date, pto_policy, company_holidays
      if company_holidays.count > 0  && company_holidays.include?(date)
         return true if pto_policy.working_days.include?('Holiday')
      else
         return true if pto_policy.working_days.include?(date.strftime("%A"))
      end
      return false
    end
  end
end
