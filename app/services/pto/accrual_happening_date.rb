module Pto
  class AccrualHappeningDate

    def initialize policy, start_date
      @pto_policy = policy
      @start_date = start_date
    end

    def perform
      calculate_first_accrual_happening_date
    end

    def get_start_date
      start_date_of_accrual
    end

    private

    def calculate_first_accrual_happening_date
      first_accrual_happening_date
    end

    def start_date_of_accrual
      case @pto_policy.accrual_frequency
        when 'daily'
          @start_date
        when 'weekly'
          @start_date.wday == 1 ? @start_date : @start_date.next_week
        when 'bi-weekly'
          @start_date.wday == 1 ? @start_date : @start_date.next_week
        when 'semi-monthly'
          @start_date.day == 1 || @start_date.day == 16 ? @start_date : (@start_date.day < 16 ? (@start_date.beginning_of_month) + 15.day : @start_date.next_month.beginning_of_month)
        when 'monthly'
          @start_date.day == 1 ? @start_date : @start_date.next_month.beginning_of_month
        when 'annual'
          @start_date.next_year.beginning_of_year
        end
    end

    def first_accrual_happening_date
      case @pto_policy.accrual_frequency
        when 'daily'
          @start_date
        when 'weekly'
          allocate_accruals_at_start? ? @start_date : @start_date.end_of_week
        when 'bi-weekly'
          allocate_accruals_at_start? ? @start_date : @start_date.end_of_week + 7
        when 'semi-monthly'
          get_date_for_semi_monthly
        when 'monthly'
          allocate_accruals_at_start? ? @start_date : @start_date.end_of_month
        when 'annual'
          @start_date
        end
    end

    def allocate_accruals_at_start?
      @pto_policy.allocate_accruals_at == "start"
    end

    def get_date_for_semi_monthly
      if allocate_accruals_at_start?
        @start_date
      elsif !allocate_accruals_at_start? and @start_date.strftime("%d").to_i <= 15
        @start_date.beginning_of_month + 14
      elsif !allocate_accruals_at_start? and @start_date.strftime("%d").to_i > 15
        @start_date.end_of_month
      end
    end

  end
end
