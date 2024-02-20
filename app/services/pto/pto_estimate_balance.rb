module Pto
  class PtoEstimateBalance

    def initialize assigned_policy, estimate_date, company, current_date=nil, pto_id=nil
      @current_date    = current_date ? current_date : company.time.to_date
      @estimate_date   = estimate_date.to_time.to_date rescue @current_date
      @assigned_policy = assigned_policy
      termination_date = @assigned_policy.user.termination_date
      @estimate_date   = termination_date if termination_date && @estimate_date > termination_date
      @policy          = assigned_policy.pto_policy
      @pto_adjustments = @assigned_policy.pto_adjustments.includes(:creator).where(effective_date: (@current_date+1.day)..@estimate_date)
      @company         = company
      @audit_logs      = @assigned_policy.pto_balance_audit_logs.to_a
      @pto_id          = pto_id
    end

    def perform
      if @assigned_policy.user.state == "active"
        get_range_and_future_logs
        @audit_logs.delete_if(&:blank?)
        @audit_logs.sort_by{ |log| log.created_at }.reverse
      end
      Pto::Shared.object(@assigned_policy.total_balance , @audit_logs, @assigned_policy.carryover_balance)
    end

    def get_policy_balance_for_pto
      if @assigned_policy.user.state == "active"
        get_range_and_future_logs
        @audit_logs.delete_if(&:blank?)
        @audit_logs.sort_by{ |log| log.created_at }.reverse
      end
      @assigned_policy.balance -= ((@audit_logs.select { |log| log.balance_updated_at == @estimate_date && log.description.include?("Accr")}).first.balance_added rescue 0) if @policy.allocate_accruals_at == "end"
      return {balance: @assigned_policy.balance, carryover_balance: @assigned_policy.carryover_balance}
    end

    private
    def get_range_and_future_logs
      if @estimate_date >= @current_date
        if @policy.allocate_accruals_at == "start"
          range = get_number_accrual_periods_start.to_a if is_estimated_date_greater_than_start_date?
        elsif @policy.allocate_accruals_at == "end"
          range = get_number_accrual_periods_end.to_a if is_estimated_date_greater_than_start_date?
        end
        range.unshift(@assigned_policy.start_of_accrual_period) if !@assigned_policy.is_balance_calculated_before && @assigned_policy.start_of_accrual_period <= @estimate_date && (@policy.allocate_accruals_at == "start" || @policy.accrual_frequency == 'annual')
        return nil if @current_date > @estimate_date && range && range.count == 0
        range.uniq! if range
        range.sort! if range
        adjustment_renewal_and_expire_balance_logs(@current_date..@estimate_date, range) if range == nil || range.count == 0
        adjustment_renewal_and_expire_balance_logs(@current_date..(range[0]-1.day), range) if range && range.count > 0 && range.first>@current_date
        add_range_accruals range if range
      end
      adjustment_renewal_and_expire_balance_logs((range.last+1.day)..@estimate_date, range) if range && range.count > 0 && range.last<@estimate_date
    end

    def add_range_accruals range
      pre_date = range[0]
      range.each do |date|
        adjustment_renewal_and_expire_balance_logs (pre_date..date), range
        pre_date = date + 1.day
        if should_accrue?(date)
          response = Pto::ManagePtoBalances.new(nil, @company).estimate_balance(@policy, @assigned_policy, date)
          @assigned_policy.balance += response[:estimated_balance]
          @audit_logs << response[:audit_logs]
          if !@assigned_policy.is_balance_calculated_before && response[:audit_logs]
            @assigned_policy.is_balance_calculated_before = true
            @assigned_policy.balance_updated_at = date
          end
          if @policy.accrual_frequency == 'bi-weekly' && @assigned_policy.balance_updated_at && (date-@assigned_policy.balance_updated_at).to_i >7 && @assigned_policy.is_balance_calculated_before
            @assigned_policy.balance_updated_at = date
          end
        end
        deduct_pto_balance(date) if @policy.allocate_accruals_at == "start"
      end
    end
    def adjustment_logs date
      logs = get_adjustments_amount(@pto_adjustments.where(effective_date: date))
      logs.each do |log|
        @audit_logs << log
      end
    end

    def get_adjustments_amount pto_adjustments
      logs = []
      pto_adjustments.each do |pto_adjustment|
        log = PtoBalanceAuditLog.new(balance_updated_at: pto_adjustment.effective_date, description: description_adjustment(pto_adjustment), created_at: @company.time)
        if pto_adjustment.operation == "added"
          @assigned_policy.balance += pto_adjustment.hours
          log.balance_added = pto_adjustment.hours
        elsif pto_adjustment.operation == "subtracted"
          @assigned_policy.balance -= pto_adjustment.hours
          log.balance_used = pto_adjustment.hours
        end
        log.balance = @assigned_policy.balance + @assigned_policy.carryover_balance
        logs << log
      end
      logs
    end

    def description_adjustment pto_adjustment
      "Manual adjustment made by #{pto_adjustment.creator.display_name}"
    end

    def get_number_accrual_periods_start
      case @policy.accrual_frequency
        when 'daily'
          get_number_of_days_start
        when 'weekly'
          get_number_of_mondays
        when 'monthly'
          get_number_of_month_start
        when 'annual'
          []
        when 'semi-monthly'
          get_number_of_start_and_mid_month
        when 'bi-weekly'
          get_number_of_mondays
      end
    end

    def get_number_accrual_periods_end
      case @policy.accrual_frequency
        when 'daily'
          get_number_of_days_end
        when 'weekly'
          get_number_of_sundays
        when 'monthly'
          get_number_of_month_end
        when 'annual'
          []
        when 'semi-monthly'
          get_number_of_end_and_mid_month
        when 'bi-weekly'
          get_number_of_sundays
      end
    end

    def get_number_of_days_start
      (@current_date..@estimate_date)
    end

    def get_number_of_days_end
      (@current_date..@estimate_date)
    end

    def get_number_of_mondays
      (@current_date..@estimate_date).select { |d| d.wday == 1 }
    end

    def get_number_of_sundays
      (@current_date..@estimate_date).select { |d| d.wday == 0 }
    end

    def get_number_of_month_start
      (@current_date..@estimate_date).select { |d| d == d.beginning_of_month }
    end

    def get_number_of_month_end
      (@current_date..@estimate_date).select { |d| d == d.end_of_month }
    end

    def get_number_of_start_year
      (@current_date..@estimate_date).select { |d| d == d.beginning_of_year }
    end

    def get_number_of_end_year
      (@current_date..@estimate_date).select { |d| d == d.end_of_year }
    end

    def get_number_of_start_and_mid_month
      (@current_date..@estimate_date).select { |d| d.day == 1 || d.day == 16 }
    end

    def get_number_of_end_and_mid_month
      (@current_date..@estimate_date).select { |d| d.day == 15 || d.day == d.end_of_month.day }
    end

    def get_number_of_bi_weekly
      date = @assigned_policy.balance_updated_at != nil ? (@assigned_policy.balance_updated_at.to_date + 14.day) : @assigned_policy.start_of_accrual_period.to_date
      range = []
      while true do
        if date <= @estimate_date
          range.concat (@current_date..@estimate_date).select { |d| d == date }
        else
          return range
        end
        date += 14.day
      end
    end

    def is_estimated_date_greater_than_start_date?
      @assigned_policy.start_of_accrual_period <= @estimate_date
    end

    def adjustment_renewal_and_expire_balance_logs range, accrual_range
      range.each do |date|
        expire_carryover_balance(date) if expire_balance? date
        renew_the_policy(date) unless @company.time.to_date == date && @company.time.hour > 4
        adjustment_logs(date)
        deduct_pto_balance(date) unless accrual_range && accrual_range.include?(date) && @policy.allocate_accruals_at == "start"
      end
    end

    def deduct_pto_balance date
      @assigned_policy.pto_requests.where(begin_date: date, balance_deducted: false, status: [PtoRequest.statuses["pending"], PtoRequest.statuses["approved"]]).where.not(id: @pto_id).try(:each) do |pto|
        updated_balance = pto.get_balance_after_deduction @assigned_policy, pto.balance_hours
        @assigned_policy.balance = updated_balance[:new_balance]
        @assigned_policy.carryover_balance = updated_balance[:new_carryover_balance]
        description = pto.begin_date == pto.end_date ? "Used(#{pto.begin_date})" :  "Used(#{pto.begin_date} to #{pto.end_date})"
        @audit_logs << PtoBalanceAuditLog.new(balance: @assigned_policy.total_balance, balance_used: pto.balance_hours, balance_updated_at: pto.begin_date, description: description, created_at: @company.time)
      end
    end

    def renew_the_policy date
      policy_renewal_date = @policy.accrual_renewal_time == 'anniversary_date' ? @assigned_policy.user.start_date : @policy.renewal_date(@policy.company.time.to_date)
      renewal_date = date if date.day == policy_renewal_date.day && date.month  == policy_renewal_date.month
      return if renewal_date.nil? || renewal_date < @assigned_policy.first_accrual_happening_date || renewal_happened_today(renewal_date)
      old_balance = @assigned_policy.total_balance
      working_hours = @assigned_policy.pto_policy.working_hours
      if old_balance > 0
        if !@policy.carry_over_unused_timeoff
          @assigned_policy.balance = 0
          @audit_logs << PtoBalanceAuditLog.new(balance: @assigned_policy.carryover_balance, balance_used: old_balance, balance_updated_at: renewal_date, description: "Policy Renewed", created_at: @company.time)
        elsif @policy.carry_over_unused_timeoff
          if (!@policy.has_maximum_carry_over_amount || (@policy.has_maximum_carry_over_amount && @policy.maximum_carry_over_amount * working_hours >= old_balance ))
            @assigned_policy.balance = 0
            @assigned_policy.carryover_balance = old_balance
          elsif @policy.has_maximum_carry_over_amount && (@policy.maximum_carry_over_amount* working_hours) < old_balance
            @assigned_policy.balance = 0
            @assigned_policy.carryover_balance = @policy.maximum_carry_over_amount * working_hours
            @audit_logs << PtoBalanceAuditLog.new(balance: @assigned_policy.carryover_balance, balance_used: (old_balance - @policy.maximum_carry_over_amount * working_hours), balance_updated_at: renewal_date, description: "Policy Renewed", created_at: @company.time)
          end
        end
      elsif old_balance < 0 && @policy.can_obtain_negative_balance && !@policy.carry_over_negative_balance
        @assigned_policy.balance = 0
        @audit_logs << PtoBalanceAuditLog.new(balance: @assigned_policy.carryover_balance, balance_added: old_balance.abs, balance_updated_at: renewal_date, description: "Policy Renewed", created_at: @company.time)
      end
      if @assigned_policy.is_balance_calculated_before && @policy.accrual_frequency == 'annual'
        response = Pto::ManagePtoBalances.new(nil, @company).estimate_balance(@policy, @assigned_policy, date)
        @assigned_policy.balance += response[:estimated_balance]
        @audit_logs << response[:audit_logs]
      end 
    end

    def expire_carryover_balance date
      expiry_date = date if date.day == @policy.carryover_amount_expiry_date.day && date.month  == @policy.carryover_amount_expiry_date.month
      return if expiry_date.nil? || expiry_date < @assigned_policy.first_accrual_happening_date || balance_expired_today(expiry_date)
      carryover_balance = @assigned_policy.carryover_balance
      @assigned_policy.carryover_balance = 0
      @audit_logs << PtoBalanceAuditLog.new(balance: @assigned_policy.balance, balance_used: carryover_balance, balance_updated_at: expiry_date, description: "Carryover Expired", created_at: @company.time)
    end

    def renewal_happened_today date
      date == @current_date
    end

    def balance_expired_today date
      date == @current_date
    end

    def expire_balance? date
      @policy.expire_unused_carryover_balance && @policy.carryover_amount_expiry_date.present? && @assigned_policy.carryover_balance > 0 && !(@company.time.to_date == date && @company.time.hour > 2)
    end

    def should_accrue? date
      @assigned_policy.start_of_accrual_period <= date && !((@policy.allocate_accruals_at == "start" && @company.time.to_date == date) || (@policy.allocate_accruals_at == "end" && @company.time.to_date == date && @company.time.hour > 18) )
    end
  end
end
