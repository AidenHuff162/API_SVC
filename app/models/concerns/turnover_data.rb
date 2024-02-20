module TurnoverData
  extend ActiveSupport::Concern

  def calculate_custom_date_turnovers params
    date_filter = params['date_filter']
    starting_month = (date_filter - 11.months).beginning_of_month
    company_users = get_company_turnover_users(params)
    offboarded_users = company_users.where.not(current_stage: [0, 1, 2, 8, 12, 13, 14])
                                    .departed_in_range(starting_month.to_s, date_filter.to_s)

    offboarded = []
    starting_headcount = []
    annualized_turnover = []
    current_month_count = 0

    (0..11).reverse_each do |month_index|
      month = date_filter.to_date - month_index.months
      new_date = Date.parse("#{month.year}-#{month.month}-01")
      end_of_month = month_index == 0 ? date_filter.to_s : new_date.end_of_month
      current_month_arrivals = company_users.arrived_and_active_in_range(new_date.to_s, end_of_month.to_s).count                                             
      current_month_departures = offboarded_users.departed_in_range(new_date.to_s, end_of_month.to_s).count

      current_month_count = if month_index == 11 
        company_users.active_till_date(end_of_month.to_s).count 
      else 
        current_month_count + current_month_arrivals - current_month_departures
      end

      starting_month_headcount = current_month_count + current_month_departures - current_month_arrivals  
      current_month_average = (starting_month_headcount + current_month_count)/2.0
      
      if current_month_average != 0
        annualized_turnover_rate = ((current_month_departures*100)/current_month_average).round(1)
      else
        annualized_turnover_rate = 0
      end

      annualized_turnover.push(annualized_turnover_rate)
      offboarded.push(current_month_departures)

      starting_headcount.push(current_month_count)
    end

    termination_counts = get_termination_counts(offboarded_users)
    service_counts = get_service_counts(offboarded_users)
    rehire_counts = get_rehire_counts(offboarded_users)

    {
      starting_headcount: starting_headcount,
      total_offboarded: offboarded_users.count,
      annualized_turnover: annualized_turnover,
      offboarded: offboarded,
      termination_counts: termination_counts,
      service_counts: service_counts,
      rehire_counts: rehire_counts
    }
  end

  private

  def get_company_turnover_users(params)
    filters = JSON.parse(params['filters'])
    option_ids = []
    team_ids = []
    location_ids = []
    termination_types = []
    if filters.present?
      filters['mcq'].try(:each) do |k,v|
        option_ids.push v
      end
      filters['employment_status'].try(:each) do |k,v|
        option_ids.push v
      end
      filters['Departments'].try(:each) do |k,v|
        team_ids.push v
      end
      filters['Locations'].try(:each) do |k,v|
        location_ids.push v
      end
      filters['termination_type'].try(:each) do |k,v|
        termination_types.push v
      end
    end

    option_ids = option_ids.reject { |ids| ids.empty? }

    company_users = self.users.where(super_user: false)
    company_users = company_users.where(location_id: location_ids) unless location_ids.first.blank?
    company_users = company_users.where(team_id: team_ids) unless team_ids.first.blank?
    company_users = company_users.includes(:custom_field_values).where(custom_field_values: {custom_field_option_id: option_ids}) unless option_ids.first.blank?
    company_users = company_users.where(termination_type: termination_types) unless termination_types.first.blank?
    company_users
  end

  def get_termination_counts offboarded_users
    offboarded_users.group('users.termination_type').order('COUNT(users.id) DESC').count
  end

  def get_service_counts offboarded_users
    offboarded_users.group("(CASE
                              WHEN (last_day_worked - start_date) < 183 THEN 1
                              WHEN (last_day_worked - start_date) >= 183 AND (last_day_worked - start_date) < 365 THEN 2
                              WHEN (last_day_worked - start_date) >= 365 AND (last_day_worked - start_date) < 1095 THEN 3
                              WHEN (last_day_worked - start_date) >= 1095 AND (last_day_worked - start_date) < 1825 THEN 5
                              WHEN (last_day_worked - start_date) >= 1825 AND (last_day_worked - start_date) < 3650 THEN 10
                              WHEN (last_day_worked - start_date) >= 3650 THEN 11
                              ELSE 0
                            END)").order('COUNT(users.id) DESC').count
  end

  def get_rehire_counts offboarded_users
    offboarded_users.group('users.eligible_for_rehire').order('COUNT(users.id) DESC').count
  end

end
