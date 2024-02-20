module HrisIntegrationsService
  module Xero
    class CreateLeaveApplicationsInXero
      attr_reader :user, :pto_request, :company, :params_builder_service

      delegate :create_loggings, to: :helper_service
      delegate :create_leave_applications, :fetch_user, :post_request, :fetch_payroll_calendar, to: :hris_service

      def initialize(pto_request)
        @pto_request = pto_request
        @user = pto_request.user
        @company = @user.company
        @params_builder_service = HrisIntegrationsService::Xero::ParamsBuilder.new
      end

      def create_leave_application
        assign_leave_type
        pay_periods = []
        response = fetch_payroll_calendar
        calendar_type = response[0]['CalendarType'] if response.present?
        date = DateTime.strptime((response[0]['ReferenceDate'][6..].split('+')[0].to_f / 1000).to_s, '%s').to_date
        @status = pto_request.begin_date >= date ? 'SCHEDULED' : 'POSTED'

        if pto_request.partial_day_included
          case calendar_type
          when 'WEEKLY'
            date += 7
            date += 7 while pto_request.begin_date > date
            date -= 1
          when 'FORTNIGHTLY'
            date += 14
            date += 14 while pto_request.begin_date > date
            date -= 1
          when 'MONTHLY'
            date += 1.month
            date += 1.month while pto_request.begin_date > date
            date -= 1
          when 'TWICEMONTHLY'
            pay_period_dates = get_summarized_pay_period_dates(pto_request, date)[0]
            if pay_period_dates
              lower_range_date, upper_range_date = pay_period_dates
              date = (pto_request.end_date < lower_range_date) ? lower_range_date : upper_range_date
            end
          when 'FOURWEEKLY'
            date += 28
            date += 28 while pto_request.begin_date > date
            date -= 1
          when 'QUARTERLY'
            date += 3.months
            date += 3.months while pto_request.begin_date > date
            date -= 1
          end
          pay_periods.push(pay_period(date.to_s, pto_request.get_balance))
        else
          case calendar_type
          when 'WEEKLY'
            date += 1.week
            date += 1.week while pto_request.begin_date > date
            end_date = date - 1
            begin_date = pto_request.begin_date
            date = end_date
            date = pto_request.get_end_date if end_date > pto_request.get_end_date
            days, begin_date = calculate_days(begin_date, date)
            pay_periods.push(pay_period(end_date.to_s, (pto_request.pto_policy.working_hours * days).round(1)))

            while pto_request.get_end_date > end_date
              end_date += 7.days
              date = end_date
              date = pto_request.get_end_date if end_date > pto_request.get_end_date
              days, begin_date = calculate_days(begin_date, date)
              pay_periods.push(pay_period(end_date.to_s, (pto_request.pto_policy.working_hours * days).round(1)))
            end
          when 'MONTHLY'
            date += 1.month
            date += 1.month while pto_request.begin_date > date
            end_date = date - 1
            begin_date = pto_request.begin_date
            date = end_date
            date = pto_request.get_end_date if end_date > pto_request.get_end_date
            days, begin_date = calculate_days(begin_date, date)
            pay_periods.push(pay_period(end_date.to_s, (pto_request.pto_policy.working_hours * days).round(1)))

            while pto_request.get_end_date > end_date
              end_date += 1.month
              date = end_date
              date = pto_request.get_end_date if end_date > pto_request.get_end_date
              days, begin_date = calculate_days(begin_date, date)
              pay_periods.push(pay_period(end_date.to_s, (pto_request.pto_policy.working_hours * days).round(1)))
            end

          when 'TWICEMONTHLY'
            pay_period_dates = get_summarized_pay_period_dates(pto_request, date)

            if pay_period_dates.compact.length == 1
              pay_periods << create_pay_period_entry(pto_request, pay_period_dates.first[1], pto_request.begin_date, pto_request.end_date, true)
            else
              pay_period_dates.compact.each_with_index do |period, index|
                begin_date = index.zero? ? pto_request.begin_date : period[0]
                end_date = index == (pay_period_dates.length - 1) ? pto_request.end_date : period[1]
                pay_periods << create_pay_period_entry(pto_request, period[1], begin_date, end_date)
              end
            end
          end
        end
        params = params_builder_service.build_leave_application_params(user, pto_request, pay_periods)
        response = create_leave_applications(params)
        if response.ok?
          body = JSON.parse(response.body)
          log(response.code, 'Create Leave Applications in Xero - SUCCESS', { params: params, result: body }, params)
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
        else
          log(response.code, 'Create Leave Applications in Xero - Failure',
              { params: params, message: response.message, response: response.body.to_s, effected_profile: "#{pto_request.inspect} (#{pto_request.id})" }, params)
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
        end
      rescue Exception => e
        log(500, 'Create Leave Applications in Xero - Failure',
            { message: e.message, params: params, effected_profile: "#{pto_request.inspect} (#{pto_request.id})" }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end

      private

      def create_pay_period_entry(pto_request, pay_period_date, begin_date, end_date, is_single_period = false)
        end_date = pto_request.get_end_date if is_single_period
        days, _begin_date = calculate_days(begin_date, end_date)
        pay_period(pay_period_date.to_s, (pto_request.pto_policy.working_hours * days).round(1))
      end

      def calculate_days(begin_date, end_date)
        days = 0
        while begin_date <= end_date
          days += 1 if valid_date(begin_date)
          begin_date += 1
        end
        [days, begin_date]
      end

      def pay_period(date, balance)
        {
          'LeavePeriodStatus' => @status,
          'PayPeriodEndDate' => date,
          'NumberOfUnits' => balance
        }
      end

      def valid_date(date)
        [1, 2, 3, 4, 5].include?(date.wday)
      end

      def log(status, action, result, request = nil)
        create_loggings(company, 'Xero', status, action, result, request)
      end

      def helper_service
        HrisIntegrationsService::Xero::Helper.new
      end

      def hris_service
        HrisIntegrationsService::Xero::HumanResource.new(company, nil, @user.id)
      end

      def check_leave_assigned_already
        response = fetch_user(user)
        leave_assigned = false
        response['Employees'][0]['PayTemplate']['LeaveLines'].each do |line|
          if line['LeaveTypeID'] == pto_request.pto_policy.xero_leave_type_id
            leave_assigned = true
            break
          end
        end

        [leave_assigned, response['Employees'][0]['PayTemplate']['LeaveLines']]
      end

      def assign_leave_type
        leave_assigned, existing_leave = check_leave_assigned_already
        return if leave_assigned

        params = params_builder_service.build_leave_assign_params(user, pto_request, existing_leave)
        response = post_request(params)
        if response.ok?
          body = JSON.parse(response.body)
          log(response.code, 'Assign Leave Type in Xero - SUCCESS', { params: params, result: body }, params)
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
        else
          log(response.code, 'Assign Leave Type in Xero - Failure',
              { params: params, message: response.message, user: user, data: response.body.to_s, effected_profile: "#{pto_request.inspect} (#{pto_request.id})" }, params)
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
        end
      rescue Exception => e
        log(500, 'Assign Leave Type in Xero - Failure',
            { message: e.message, params: params, user: user, effected_profile: "#{pto_request.inspect} (#{pto_request.id})" }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end

      def get_calculated_twice_monthly_date(pto_request, pay_period_ranges)
        sub_pay_period_ranges = []
        if pto_request.begin_date == pto_request.end_date
          return [pay_period_ranges.select{ |d| d[1] >= pto_request.end_date }[0]]
        else
          s_index = 0
          e_index = 0
          pay_period_ranges.each_with_index do |period, index|
            s_index = index if pto_request.begin_date >= period[0] && pto_request.begin_date <= period[1]
            e_index = index if pto_request.end_date >= period[0] && pto_request.end_date <= period[1]
          end
          pay_period_ranges.each_with_index { |item, index| sub_pay_period_ranges << item if s_index <= index && e_index >= index }
          return sub_pay_period_ranges
        end
      end

      def calculate_pay_period_complete_range(pto_last_date, reference_date, period_range)
        reference_date = calculate_individual_pay_period(reference_date, period_range) while reference_date <= pto_last_date
      end

      def calculate_individual_pay_period(reference_date, period_range)
        origional_reference_date = reference_date
        next_ref_date = reference_date.next_month
        period_range << [reference_date, (reference_date + 14.days).to_date]
        reference_date = (reference_date + 14.days).to_date
        days_to_be_added = get_days_to_be_added(reference_date, next_ref_date)

        period_range << [(reference_date + 1.day).to_date, (reference_date + days_to_be_added.days).to_date]
        next_ref_date
      end

      def get_days_to_be_added(reference_date, next_ref_date)
        (reference_date.end_of_month.day - reference_date.day) if next_ref_date.day == 1
        ((get_exact_day(origional_reference_date, next_ref_date) - 1) - reference_date.day) if reference_date.month == next_ref_date.month
        (reference_date.end_of_month.day - reference_date.day) + (next_ref_date.day - next_ref_date.beginning_of_month.day)
      end

      def get_exact_day(org_ref_date, next_ref_date)
        org_ref_date.day == next_ref_date.day ? org_ref_date.day : next_ref_date.end_of_month.day
      end

      def get_summarized_pay_period_dates(pto_request, reference_date)
        pay_period_ranges = []
        calculate_pay_period_complete_range(pto_request.end_date, reference_date, pay_period_ranges)
        get_calculated_twice_monthly_date(pto_request, pay_period_ranges)
      end
    end
  end
end
