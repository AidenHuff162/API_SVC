
module Pto
  class ManagePtoBalances

    def initialize allocate_accruals_at, company, update_assigned_policies = false, custom_date = nil
      @current_date = Time.now.in_time_zone(company.time_zone).to_date
      @current_date = custom_date if custom_date.present?
      @company = company
      @allocate_accruals_at = allocate_accruals_at
      @pto_policy = nil
      @assigned_policy = nil
      @update_assigned_policies = update_assigned_policies
    end

    def perform
      accrual_frequencies = []
      if accrue_balance_at_start_of_period?
        accrual_frequencies = get_accrual_frequencies_for_starting_periods
      elsif accrue_balance_at_end_of_period?
        accrual_frequencies = get_accrual_frequencies_for_ending_periods
      end
      pto_policies = fetch_pto_policies(accrual_frequencies)
      add_balance_to_assigned_policies(pto_policies)
    end

    def estimate_balance policy, assigned_policy, date
      return Pto::Shared.object(0,nil) if assigned_policy.balance_updated_at.present? and assigned_policy.balance_updated_at == date
      @pto_policy = policy
      @assigned_policy = assigned_policy
      @current_date = date
      @update_assigned_policies = true if !assigned_policy.is_balance_calculated_before
      @allocate_accruals_at = policy.accrual_frequency == 'annual' ? 0 : PtoPolicy.allocate_accruals_ats[policy.allocate_accruals_at]
      @policy_start_date = @assigned_policy.start_of_accrual_period
      user = @assigned_policy.user
      return Pto::Shared.object(0,nil, @assigned_policy.carryover_balance) if stop_accrual_date(user)
      balance = get_estimated_balance
      log = PtoBalanceAuditLog.new(balance_updated_at: @current_date, description: "Accrual for #{audit_log_dates[:start_date].strftime("%d/%m/%Y")} to #{audit_log_dates[:end_date].strftime("%d/%m/%Y")}", balance_added: balance, balance: @assigned_policy.balance + @assigned_policy.carryover_balance + balance, created_at: @company.time) if balance && balance >= 0
      balance = 0 if balance.nil? 
      Pto::Shared.object(balance,log, @assigned_policy.carryover_balance)
    end

    def actual_range
      dates = {}
      if need_to_caculate_prorated_amount? && @pto_policy.first_accrual_method == "prorated_amount"
        dates[:start_date] = get_current_period_range.first
        dates[:end_date]   = get_current_period_range.last
      else
        dates[:start_date] = accrual_period_range[:start_date]
        dates[:end_date]   = accrual_period_range[:end_date]
      end
      dates
    end

    def audit_log_dates
      date_range = actual_range
      date_range[:end_date] = @assigned_policy.user.termination_date if is_user_termination_date_in_range?
      return date_range
    end

    def get_estimated_balance
      return if @assigned_policy.pto_policy.accrual_frequency == 'bi-weekly' && !((@assigned_policy.balance_updated_at.blank? && @assigned_policy.first_accrual_happening_date == @current_date) || (@assigned_policy.balance_updated_at.present? && ((@current_date - @assigned_policy.balance_updated_at).to_i > 7)))
      balance_to_add = calculate_rate
    end

    def annual_renewal_of_pto_policies assigned_policies
      add_balance_to_individual_assigned_policies(assigned_policies)
    end

    def calculate_initial_balances assigned_policies
      return if !accrue_balance_at_start_of_period? or assigned_policies.size == 0
      add_balance_to_individual_assigned_policies(assigned_policies)
    end

    def add_initial_balance_for_policy_starting_at_custom_accrual_date
      if accrue_balance_at_start_of_period?
        assigned_policies = AssignedPtoPolicy.joins(:pto_policy).where("assigned_pto_policies.is_balance_calculated_before = ? and (pto_policies.allocate_accruals_at = ? or pto_policies.accrual_frequency = ?) and pto_policies.is_enabled = ? and pto_policies.unlimited_policy = ? and (assigned_pto_policies.first_accrual_happening_date = ? or assigned_pto_policies.first_accrual_happening_date < ?) and pto_policies.company_id = ?",false, 0, PtoPolicy.accrual_frequencies['annual'], true, false, @current_date, @current_date, @company.id)
      elsif !accrue_balance_at_start_of_period?
        assigned_policies = AssignedPtoPolicy.joins(:pto_policy).where("assigned_pto_policies.is_balance_calculated_before = ? and pto_policies.allocate_accruals_at = ? and pto_policies.is_enabled = ? and pto_policies.unlimited_policy = ? and (assigned_pto_policies.first_accrual_happening_date = ? or assigned_pto_policies.first_accrual_happening_date < ?) and pto_policies.company_id = ?",false,  1, true, false, @current_date, @current_date, @company.id)
      end
      add_balance_to_individual_assigned_policies(assigned_policies.eagerload_users_and_requests)
    end

    def calculate_last_accruals assigned_policies
      add_balance_to_individual_assigned_policies assigned_policies
    end

    def add_balance_to_individual_assigned_policies assigned_pto_policies, last_accrual=nil
      assigned_pto_policies.each do |assigned_policy|
        begin
          @assigned_policy = assigned_policy
          @policy_start_date = @assigned_policy.is_balance_calculated_before ? @current_date : @assigned_policy.start_of_accrual_period
          @pto_policy = assigned_policy.pto_policy if @update_assigned_policies
          user = User.find_by(id: assigned_policy.user_id)
          next if user_is_not_valid(user, last_accrual, assigned_policy) || stop_accrual_date(user)
          update_balance
        rescue Exception=>e
          LoggingService::GeneralLogging.new.create(@company, 'Assigning Balance', {result: "Failed to add accruals for assigned_policy with id #{assigned_policy.id}", error: e.message}, 'PTO')           
        end
      end
    end



    private
    def add_balance_to_assigned_policies policies
      policies.each do |policy|
        @pto_policy = policy
        add_balance_to_individual_assigned_policies(@pto_policy.assigned_pto_policies.where('first_accrual_happening_date <= ? and is_balance_calculated_before = ?', @current_date, true))
      end
    end

    def duplicate_accruals? assigned_policy
      assigned_policy.balance_updated_at == @current_date
    end

    def update_balance
      if @assigned_policy.pto_policy.accrual_frequency == 'bi-weekly'
        update_bi_weekly_balance
      else
        update_policy_balance
      end
    end

    def update_policy_balance
      balance_to_add = calculate_rate

      update_value_in_database(balance_to_add)
    end

    def update_bi_weekly_balance
      if @assigned_policy.balance_updated_at.blank? || is_user_termination_date_in_range? || (@assigned_policy.balance_updated_at.present? and ((@current_date - @assigned_policy.balance_updated_at).to_i > 7))
        
        balance_to_add = calculate_prorated_amount(get_rate_per_frequency) if first_accrual_and_prorated
        balance_to_add = calculate_rate if !first_accrual_and_prorated
        update_value_in_database(balance_to_add)
      end
    end

    def calculate_rate
      amount = 0
      if is_user_termination_date_in_range?
        amount = calculate_rate_for_the_last_time
      elsif need_to_caculate_prorated_amount?
        amount = calculate_rate_for_the_first_time
      else
        rate = 0
        @pto_policy.accrual_rate_unit == 'days' ? rate = get_policy_tenureship_rate * @pto_policy.working_hours : rate = get_policy_tenureship_rate
        rate = rate * get_number_of_aquisition_period_of_iterations
        amount = (rate.to_f/get_frequency_iterations.to_f)
      end
      return 0 if @assigned_policy.pto_policy.has_max_accrual_amount? and @assigned_policy.total_balance >= @assigned_policy.pto_policy.accrual_max_amount
      return @assigned_policy.pto_policy.accrual_max_amount - @assigned_policy.total_balance if @assigned_policy.pto_policy.has_max_accrual_amount? and (@assigned_policy.total_balance + amount) >= @assigned_policy.pto_policy.accrual_max_amount
      amount
    end

    def calculate_rate_for_the_first_time
      amount = 0
      policy_rate = @pto_policy.accrual_rate_unit == 'days' ? (get_policy_tenureship_rate * @pto_policy.working_hours) : get_policy_tenureship_rate
      policy_rate = policy_rate * get_number_of_aquisition_period_of_iterations
      rate_per_frequency = (policy_rate.to_f/get_frequency_iterations.to_f)
      amount = @pto_policy.first_accrual_method == 'full_amount' || @pto_policy.accrual_frequency == 'daily' ? rate_per_frequency : calculate_prorated_amount(rate_per_frequency)
    end

    def get_rate_per_frequency
      policy_rate = @pto_policy.accrual_rate_unit == 'days' ? (get_policy_tenureship_rate * @pto_policy.working_hours) : get_policy_tenureship_rate
      policy_rate = policy_rate * get_number_of_aquisition_period_of_iterations
      rate_per_frequency = (policy_rate.to_f/get_frequency_iterations.to_f)
    end

    def calculate_rate_for_the_last_time
      amount = 0
      policy_rate = @pto_policy.accrual_rate_unit == 'days' ? (get_policy_tenureship_rate * @pto_policy.working_hours) : get_policy_tenureship_rate
      policy_rate = policy_rate * get_number_of_aquisition_period_of_iterations
      rate_per_frequency = (policy_rate.to_f/get_frequency_iterations.to_f)
      rate_for_one_hour = rate_per_frequency/get_hours_for_accrual_period
      amount = (audit_log_dates[:start_date]..audit_log_dates[:end_date]).count * @pto_policy.working_hours * rate_for_one_hour
    end

    def check_if_accrual_renewal_date_is_greater
      month = @pto_policy.accrual_renewal_date.strftime("%m").to_i
      day = @pto_policy.accrual_renewal_date.strftime("%d").to_i
      (month >= @policy_start_date.strftime("%m").to_i )and
      (day >= @policy_start_date.strftime("%d").to_i )
    end

    def calculate_prorated_amount rate
      rate_for_one_hour = rate/get_hours_for_accrual_period
      amount = 0
      if get_current_period_range.present? && get_current_period_range.first.present? && get_current_period_range.last.present?
        amount = (get_current_period_range.count > 365 ? 365 : get_current_period_range.count) * @pto_policy.working_hours * rate_for_one_hour
      end
      amount
    end

    def get_current_period_range
      case @pto_policy.accrual_frequency
        when 'daily'
          @policy_start_date..@policy_start_date
        when 'weekly'
          @policy_start_date..@policy_start_date.end_of_week
        when 'bi-weekly'
          return get_biweekly_accrual_period_date_range
        when 'semi-monthly'
          @policy_start_date.strftime("%d").to_i <= 15 ? (@policy_start_date..@policy_start_date.beginning_of_month + 14) : @policy_start_date..@policy_start_date.end_of_month
        when 'monthly'
          @policy_start_date..@policy_start_date.end_of_month
        when 'annual'
          @policy_start_date..get_end_date_for_year(@policy_start_date)
      end
    end

    def need_to_caculate_prorated_amount?
      !@assigned_policy.is_balance_calculated_before
    end

    def get_frequency_iterations
      iterations = 0
      case @pto_policy.accrual_frequency
        when 'daily'
          iterations = 365
        when 'weekly'
          iterations = 52
        when 'bi-weekly'
          iterations = 26
        when 'semi-monthly'
          iterations = 24
        when 'monthly'
          iterations = 12
        when 'annual'
          iterations = 1
        end
      iterations
    end

    def get_hours_for_accrual_period
      hours = 0
      case @pto_policy.accrual_frequency
        when 'daily'
          hours = @pto_policy.working_hours
        when 'weekly'
          hours = 7 * @pto_policy.working_hours
        when 'bi-weekly'
          hours = 14 * @pto_policy.working_hours
        when 'semi-monthly'
          hours = @current_date.day > 15 ? (@current_date.end_of_month.day - 15) * @pto_policy.working_hours : 15 * @pto_policy.working_hours
        when 'monthly'
          hours = (@current_date.end_of_month.day * @pto_policy.working_hours)
        when 'annual'
          hours = 365 * @pto_policy.working_hours
        end
      hours
    end

    def get_end_time_for_accrual_frequency
      case @pto_policy.accrual_frequency
        when 'daily'
          @current_date
        when 'weekly'
          @current_date.end_of_week
        when 'bi-weekly'
          @current_date.end_of_week + 7
        when 'semi-monthly'
          @current_date.beginning_of_month + 14
        when 'monthly'
          @current_date.end_of_month
        when 'annual'
          @current_date.end_of_year
        end
    end

    def get_number_of_aquisition_period_of_iterations
      iterations = 0
      case @pto_policy.rate_acquisition_period
        when 'month'
          iterations = 12
        when 'week'
          iterations = 52
        when 'day'
          iterations = 365
        when 'hour_worked'
          iterations = 365 * @pto_policy.working_hours
        when 'year'
          iterations = 1
        end
      iterations
    end

    def update_value_in_database balance
      @assigned_policy.balance = @assigned_policy.balance + balance
      @assigned_policy.balance_updated_at = @current_date
      @assigned_policy.pto_balance_audit_logs.create!(balance_updated_at: @current_date, description: "Accrual for #{audit_log_dates[:start_date].strftime("%d/%m/%Y")} to #{audit_log_dates[:end_date].strftime("%d/%m/%Y")}", balance_added: balance, user_id: @assigned_policy.user_id, balance: (@assigned_policy.balance + @assigned_policy.carryover_balance))
      @assigned_policy.is_balance_calculated_before = true
      @assigned_policy.save!
    end

    def accrual_period_range
      date_range_object = {}
      case @pto_policy.accrual_frequency
        when 'daily'
          date_range_object[:start_date] = @current_date
          date_range_object[:end_date] = @current_date
        when 'weekly'
          date_range_object[:start_date] = @current_date.beginning_of_week
          date_range_object[:end_date] = @current_date.end_of_week
        when 'bi-weekly'
          date_range_object[:start_date] = get_biweekly_accrual_period_date_range.first
          date_range_object[:end_date] = get_biweekly_accrual_period_date_range.last
        when 'semi-monthly'
          if @current_date.strftime("%d").to_i <= 15
            date_range_object[:start_date] = @current_date.beginning_of_month
            date_range_object[:end_date] = @current_date.beginning_of_month + 14
          else
            date_range_object[:start_date] = @current_date.beginning_of_month + 15
            date_range_object[:end_date] = @current_date.end_of_month
          end
        when 'monthly'
          date_range_object[:start_date] = @current_date.beginning_of_month
          date_range_object[:end_date] = @current_date.end_of_month
        when 'annual'
          end_date = get_end_date_for_year(@current_date)
          date_range_object[:start_date] = (end_date - 1.year + 1.day)
          date_range_object[:end_date] = end_date
        end 
        date_range_object
    end

    def get_period_range_for_biweekly
      if @pto_policy.accrual_renewal_time == '1st_of_january'
        date = @current_date.beginning_of_year
      elsif @pto_policy.accrual_renewal_time == 'anniversary_date'
        date = @assigned_policy.user.start_date
      elsif @pto_policy.accrual_renewal_time == 'custom_date'
        date = change_year(@pto_policy.accrual_renewal_date, Time.now.year)
      end
      (@current_date - date).to_i/7
    end

    def get_accrual_frequencies_for_starting_periods
      accrual_frequency_array = [PtoPolicy.accrual_frequencies['daily']]
      if @current_date == @current_date.beginning_of_month
        accrual_frequency_array << PtoPolicy.accrual_frequencies['monthly']
        accrual_frequency_array << PtoPolicy.accrual_frequencies['semi-monthly']
      elsif @current_date.strftime('%d').to_i == 16
        accrual_frequency_array << PtoPolicy.accrual_frequencies['semi-monthly']
      end
      if @current_date.strftime("%A") == 'Monday'
        accrual_frequency_array << PtoPolicy.accrual_frequencies['weekly']
        accrual_frequency_array << PtoPolicy.accrual_frequencies['bi-weekly']
      end
      accrual_frequency_array
    end

    def get_accrual_frequencies_for_ending_periods
      accrual_frequency_array = [PtoPolicy.accrual_frequencies['daily']]
      if @current_date == @current_date.end_of_month
        accrual_frequency_array << PtoPolicy.accrual_frequencies['monthly']
        accrual_frequency_array << PtoPolicy.accrual_frequencies['semi-monthly']
      elsif @current_date.strftime('%d').to_i == 15
        accrual_frequency_array << PtoPolicy.accrual_frequencies['semi-monthly']
      end
      if @current_date.strftime("%A") == 'Sunday'
        accrual_frequency_array << PtoPolicy.accrual_frequencies['weekly']
        accrual_frequency_array << PtoPolicy.accrual_frequencies['bi-weekly']
      end
      if @current_date == @current_date.end_of_year
        accrual_frequency_array << PtoPolicy.accrual_frequencies['annual']
      end
      accrual_frequency_array
    end

    def fetch_pto_policies(accrual_frequencies)
      PtoPolicy.joins(:assigned_pto_policies).limited_and_enabled.where("pto_policies.accrual_frequency in (?) and pto_policies.allocate_accruals_at = ? and pto_policies.company_id = ? ", accrual_frequencies, @allocate_accruals_at, @company.id).distinct
    end

    def accrue_balance_at_start_of_period?
      @allocate_accruals_at == PtoPolicy.allocate_accruals_ats[:start]
    end

    def accrue_balance_at_end_of_period?
      @allocate_accruals_at == PtoPolicy.allocate_accruals_ats[:end]
    end

    def get_overlapping_holidays_and_pto_requests start_date, end_date, users_pto_requests
      overlapping_holidays = get_holidays_overlapping_with_accrual_period(start_date, end_date)
      overlapping_pto_requests = get_overlapping_pto_requests(start_date, end_date, users_pto_requests)
      overlapping_holidays.concat(overlapping_pto_requests).uniq
    end

    def get_overlapping_pto_requests start_date, end_date, users_pto_requests
      overlapping_pto_requests = []
      dates_in_period = (start_date..end_date).to_a
      users_pto_requests.each do |request|
        unless request.partial_day_included == true and (request.begin_date.to_date == request.end_date.to_date)
          overlapping_pto_requests.concat get_overlapping_pto_request(request, dates_in_period)
        end
      end
      overlapping_pto_requests
    end

    def get_holidays_overlapping_with_accrual_period start_date, end_date
      overlapping_holiday_dates = []
      holidays = @assigned_policy.user.user_holidays_in_time_period(start_date, end_date)
      holidays.each do |holiday|
        overlapping_holiday_dates.concat (start_date..end_date).to_a & (holiday.begin_date.to_date..holiday.end_date.to_date).to_a
      end
      overlapping_holiday_dates.uniq
    end

    def get_overlapping_pto_request request, dates_in_period
      if request.partial_day_included == true
        if (request.begin_date.hour > 9 || (request.begin_date.hour == 9 && request.begin_date.min > 0)) && request.end_date.hour < 17
          dates_in_period & ((request.begin_date.to_date + 1)..(request.end_date.to_date - 1)).to_a
        elsif (request.begin_date.hour > 9 || (request.begin_date.hour == 9 && request.begin_date.min > 0))
          dates_in_period & ((request.begin_date.to_date + 1)..(request.end_date.to_date )).to_a
        elsif request.end_date.hour < 17
          dates_in_period & ((request.begin_date.to_date )..(request.end_date.to_date - 1)).to_a
        else
          dates_in_period & ((request.begin_date.to_date )..(request.end_date.to_date)).to_a
        end
      else
        dates_in_period & ((request.begin_date.to_date)..(request.end_date.to_date)).to_a
      end
    end

    def get_accrual_period_date_range
      case @pto_policy.accrual_frequency
        when 'daily'
          @current_date..@current_date
        when 'weekly'
          @current_date.beginning_of_week..@current_date.end_of_week
        when 'bi-weekly'
          get_biweekly_accrual_period_date_range
        when 'semi-monthly'
          if accrue_balance_at_start_of_period?
            @current_date.strftime("%d").to_i < 16 ? (@current_date..@current_date.beginning_of_month + 14) : @current_date..@current_date.end_of_month
          else
            @current_date.strftime("%d").to_i < 16 ? (@current_date.beginning_of_month..@current_date) : @current_date.beginning_of_month+15..@current_date
          end
        when 'monthly'
          @current_date.beginning_of_month..@current_date.end_of_month
        when 'annual'
          @current_date.beginning_of_year..@current_date.end_of_year
      end
    end

    def get_biweekly_accrual_period_date_range
      termination_date = @assigned_policy.user.termination_date
      unless @update_assigned_policies
        if @current_date.strftime("%A") == "Monday" and accrue_balance_at_start_of_period?
          date = termination_date && (@current_date + 7.days) > @assigned_policy.user.termination_date ? termination_date : (@current_date + 7.days)
          @current_date.beginning_of_week..date
        elsif @current_date.strftime("%A") == "Sunday" and accrue_balance_at_end_of_period?
          date = termination_date && (@current_date.end_of_week) > @assigned_policy.user.termination_date ? termination_date : (@current_date.end_of_week)
          @current_date.beginning_of_week - 7..date
        end
      else
        if @assigned_policy.is_balance_calculated_before && termination_date && termination_date < @current_date
          return ((AssignedPtoPolicy.find_by(id: @assigned_policy.id).balance_updated_at + 1.day)..termination_date)
        else
          if accrue_balance_at_start_of_period?
            date = termination_date && (@assigned_policy.first_accrual_happening_date.end_of_week + 7.days) > @assigned_policy.user.termination_date ? termination_date : (@assigned_policy.first_accrual_happening_date.end_of_week + 7.days)
            return @assigned_policy.first_accrual_happening_date..date if first_accrual_and_prorated
            return @assigned_policy.first_accrual_happening_date.beginning_of_week..date if !first_accrual_and_prorated
          elsif accrue_balance_at_end_of_period?
            date = termination_date && (@assigned_policy.first_accrual_happening_date.end_of_week) > @assigned_policy.user.termination_date ? termination_date : (@assigned_policy.first_accrual_happening_date.end_of_week)
            return (@assigned_policy.start_of_accrual_period)..date if first_accrual_and_prorated
            return (@assigned_policy.start_of_accrual_period.beginning_of_week)..date if !first_accrual_and_prorated
          end
        end
      end
    end

    def get_policy_tenureship_rate
      policy_tenureships = @pto_policy.policy_tenureships
      return @pto_policy.accrual_rate_amount if policy_tenureships.blank?
      employement_years = (((@current_date - @assigned_policy.user.start_date) - calculate_leap_days) / 365).floor
      return @pto_policy.accrual_rate_amount if employement_years < 1 || policy_tenureships.where("year <= #{employement_years}").blank?
      return @pto_policy.accrual_rate_amount + (policy_tenureships.where("year <= #{employement_years}").max_by {|obj| obj.year }).amount
    end

    def calculate_leap_days
      start_date = @assigned_policy.user.start_date
      (start_date.year..@current_date.year).map { |y| y if Date.leap?(y) && (([start_date.year, @current_date.year].exclude?(y)) || ((start_date.year ==  y && start_date.month < 3) || (@current_date.year ==  y && @current_date.month >= 3)))}.compact.count
    end

    def is_user_termination_date_in_range?
      ((actual_range[:start_date]..actual_range[:end_date]).include? @assigned_policy.user.termination_date)
    end

    def first_accrual_and_prorated
      !@assigned_policy.is_balance_calculated_before && @pto_policy.first_accrual_method == "prorated_amount"
    end

    def get_end_date_for_year range_start_date
      range_end_date = nil
      if @pto_policy.accrual_renewal_time == 'anniversary_date'
        user_start_date = @assigned_policy.user.start_date.change(year: range_start_date.year)
        range_end_date = user_start_date <= range_start_date ? change_year(user_start_date, (range_start_date.year + 1)) : user_start_date
      else
        renewal_date = @pto_policy.accrual_renewal_date.change(year: range_start_date.year)
        range_end_date = renewal_date <= range_start_date ? change_year(renewal_date, (range_start_date.year + 1)) : renewal_date
      end
      return range_end_date - 1.day
    end

    def change_year date, year
      date.to_time.change(year: year).to_date
    end

    def user_is_not_valid(user, last_accrual, assigned_policy)
      return user.nil? || (user.termination_date.present? && user.current_stage == "departed" && last_accrual.nil?) || (user.termination_date.nil? && user.state == 'inactive') || (user.termination_date && actual_range[:start_date] > user.termination_date) || duplicate_accruals?(assigned_policy) ? true : false
    end
      
    def stop_accrual_date user
      date = user.start_date
      start_date = date.month < @current_date.month || (date.month == @current_date.month && date.day <= @current_date.day) ? change_year(date, @current_date.year) : change_year(date, (@current_date.year - 1))
      accruall_stop_date =  @pto_policy.has_stop_accrual_date ? start_date + @pto_policy.stop_accrual_date.days : nil
      return (accruall_stop_date.present? && @pto_policy.accrual_renewal_time == "anniversary_date" && (@current_date > accruall_stop_date)) ? true : false
    end
  end
end
