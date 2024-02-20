class PtoRequestService::ManagePtoRequestInterceptingData
  attr_reader :user, :pto_policy, :pto_requests, :meta
  
  def initialize(user, pto_policy, pto_requests, meta)
    @user = user
    @pto_policy = pto_policy
    @pto_requests = pto_requests
    @meta = meta
  end

  def manage_pto_requests_intercepts_without_range
    individual_pto_requests = PtoRequest.where(user_id: @user.id, pto_policy: pto_policy).individual_requests.order('begin_date ASC')
    manage_pto_requests_intercepts(individual_pto_requests) if individual_pto_requests.present?
  end

  def manage_pto_requests_intercepts_with_range(start_date, end_date)
    pto_requests = fetch_pto_requests(start_date, end_date)
    manage_pto_requests_intercepts(pto_requests, start_date, end_date)  if pto_requests.present?    
  end

  private
  
  def manage_pto_requests_intercepts(individual_pto_requests, report_start_date=nil, report_end_date=nil)
    individual_pto_requests.try(:each) do |individual_pto_request|
      start_date, end_date = initialize_start_and_end_date(individual_pto_request, report_start_date, report_end_date)

      if individual_pto_request.partial_day_included? || meta['format_data'].blank? || meta['format_data'].try(:downcase) == 'entire data range'
        manage_pto_request_list(individual_pto_request, start_date, end_date)
      else
        intercepting_list = pto_intercepts(start_date, end_date)
        manage_pto_requests_format(individual_pto_request, intercepting_list, start_date, end_date)
      end
    end
  end

  def initialize_start_and_end_date(pto, report_start_date, report_end_date)
    start_date = report_start_date.present? && report_start_date > pto.begin_date ? report_start_date : pto.begin_date
    end_date = report_end_date.present? && report_end_date < pto.get_end_date ? report_end_date : pto.get_end_date
    return start_date, end_date
  end

  def manage_pto_request_list(pto_request, start_date, end_date)

    pto_requests <<  [ pto_request.id, @user.first_name,
                       @user.last_name,
                       @user.email,
                       @pto_policy.name,
                       @pto_policy.id,
                       start_date,
                       end_date,
                       pto_request.comments.where(commenter_id: pto_request.user_id).last&.description.to_s,
                       pto_request.status,
                       (get_pto_balance(pto_request, start_date, end_date)/@pto_policy.balance_factor).round(2),
                       pto_request.created_at
                    ]
  end

  def manage_pto_requests_format(individual_pto_request, intercepting_list, start_date, end_date)
    if intercepting_list.present?
      last_intercept = nil
      intercepting_list.try(:each) do |intercept|
        pto_start_date = last_intercept.present? ? last_intercept + 1.day : start_date 
        manage_pto_request_list(individual_pto_request, pto_start_date, intercept)
        last_intercept = intercept
      end
    else
      manage_pto_request_list(individual_pto_request, start_date, end_date)
    end
  end

  def get_pto_balance(pto, start_date, end_date)
    pto.begin_date = start_date
    pto.end_date  = end_date
    pto.get_balance_used
  end
  
  def get_biweekly_intercepts(start_date, end_date)
    last_payroll_date = Date.strptime(meta['last_payroll_date'],'%m/%d/%Y')
    biweekly_intercepts = []
    count = 1
    while (last_payroll_date + (count * 14)) < end_date
      biweekly_intercepts << last_payroll_date + (count * 14)
      count += 1
    end
    count = 1
    while (last_payroll_date - (count * 14)) > start_date
      biweekly_intercepts << last_payroll_date - (count * 14)
      count += 1
    end
    return biweekly_intercepts    
  end

  def pto_intercepts(start_date, end_date)
    intercepting_events = []
    case meta['format_data'].try(:downcase)
    when 'weekly'
      (start_date..end_date).each { |date| intercepting_events << date if date.wday == 0 }
      intercepting_events.push(end_date) if intercepting_events.exclude?(end_date)
    when 'semi-monthly'
      (start_date..end_date).each { |date| intercepting_events << date if date == date.end_of_month || date.day == 15 }
      intercepting_events.push(end_date) if intercepting_events.exclude?(end_date)
    when 'monthly'
      (start_date..end_date).each { |date| intercepting_events << date if date == date.end_of_month }
      intercepting_events.push(end_date) if intercepting_events.exclude?(end_date)
    when 'bi-weekly'
      biweekly_intercepts = get_biweekly_intercepts(start_date, end_date)
      (start_date..end_date).each { |date| intercepting_events << date if biweekly_intercepts.include?(date) }
      intercepting_events.push(end_date) if intercepting_events.exclude?(end_date)
    end
  end

  def fetch_pto_requests(start_date, end_date)
    individual_pto_requests = user.pto_requests.individual_requests.where(pto_policy_id: pto_policy.id, begin_date: (start_date..end_date))
    pto_request = user.pto_requests.partner_requests.where(pto_policy_id: pto_policy.id, begin_date: (start_date..end_date)).order('begin_date ASC').take&.pto_request
    individual_pto_requests += [pto_request] if pto_request.present?
    individual_pto_requests.uniq
  end
end