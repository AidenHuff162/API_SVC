module PtoRequestOperations
  extend ActiveSupport::Concern


  def get_balance
    @pto_policy = self.pto_policy
    date_range = (self.begin_date..self.end_date).to_a
    @company_holidays = self.user.company.get_holidays_between_dates self.begin_date, self.end_date, self.user
    balance = 0
    date_range.try(:each) do |date|
      if @company_holidays.count > 0  && @company_holidays.include?(date)
        balance += get_request_balance("Holiday", date, date_range)
      else
        balance += get_request_balance(date.strftime("%A"), date, date_range)
      end
    end
    balance
  end

  def get_request_balance day, date, date_range
    amount = @pto_policy.working_days.include?(day) ? @pto_policy.working_hours : 0
    if self.partial_day_included &&  date_range.count == 1 && amount !=0
      if @pto_policy.tracking_unit == "daily_policy"
        return amount/2
      else
        return check_if_hours_amount_is_valid amount, self.balance_hours
      end
    else
      return amount
    end
  end

  def check_if_hours_amount_is_valid max_amount, amount
    return  max_amount < amount ? max_amount : amount
  end
end
