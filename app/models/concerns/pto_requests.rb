module PtoRequests
  extend ActiveSupport::Concern

  STATUSES = { partial: 'Partially out of office today',
               today: 'Out of office today',
               tomorrow: 'Out of office until tomorrow',
               until: 'Out of office until ' }

  def pto_status
    current_date, next_date = get_current_and_next_date
    status = nil
    self.pending_approved_pto_requests&.each do |pto_request|
      end_date = get_end_and_return_date(pto_request)
      if (pto_request[0].begin_date) <= current_date && end_date >= current_date
        status = get_pto_status(pto_request, current_date, next_date, end_date)
      end
    end
    status
  end

  private

  def get_pto_status(pto_request, current_date, next_date, end_date)
    if end_date == current_date && pto_request[0].partial_day_included
      status = STATUSES[:partial]
    elsif !pto_request[0].partial_day_included
      if end_date == current_date
        status = STATUSES[:today]
      elsif end_date == next_date
        status = STATUSES[:tomorrow]
      else
        status = get_return_date_status(pto_request)
      end
      new_status = checkNextPto(pto_request, status)
      status = new_status if new_status&.present?
    end
    status
  end

  def get_current_and_next_date
    [Date.today, Date.today + 1]
  end

  def get_end_and_return_date(pto_request, return_date = false)    
    last_request = pto_request[1] || pto_request[0]
    if return_date
      Pto::GetReturnDayOfUser.new.perform(last_request, true)
    else
      last_request.end_date
    end
  end

  def get_return_date_status(pto_request)
    STATUSES[:until] + get_end_and_return_date(pto_request, true)&.strftime("%B %e").to_s
  end

  def checkNextPto(current_pto_request, status)    
    next_date = get_current_and_next_date[1]
    next_pto_date = get_end_and_return_date(current_pto_request) + 1
    self.pending_approved_pto_requests&.each do |pto_request|
      if next_pto_date == pto_request[0].begin_date && !pto_request[0].partial_day_included
        end_date = get_end_and_return_date(pto_request)
        if end_date == next_date
          status = STATUSES[:tomorrow]
        else
          status = get_return_date_status(pto_request)
        end
        status = checkNextPto(pto_request, status)
      end
    end
    status
  end
end
