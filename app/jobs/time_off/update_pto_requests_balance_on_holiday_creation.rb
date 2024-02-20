module TimeOff
  class UpdatePtoRequestsBalanceOnHolidayCreation
		include Sidekiq::Worker
    sidekiq_options queue: :pto_activities

    def perform(id, holiday=nil)
      @holiday = holiday.present? ? Holiday.new(holiday) : Holiday.find_by_id(id)
      @company = @holiday&.company
      return if @holiday.nil? || @company.nil?
      user_ids = get_holiday_users.pluck(:id)

      if @holiday.multiple_dates.blank? || (@holiday.begin_date == @holiday.end_date)
        date = @holiday.begin_date
        PtoRequest.pto_requests_to_be_updated_by_holiday(@company.time.to_date, user_ids).where('begin_date = ? OR end_date = ?  OR (begin_date < ? AND end_date > ?)', date, date, date, date).find_each do |pto|
          update_pto_request_balance pto if holiday_is_not_working_day? pto
        end
      else
        PtoRequest.pto_requests_to_be_updated_by_holiday(@company.time.to_date, user_ids).find_each do |pto|
          update_pto_request_balance pto if (holiday_is_not_working_day?(pto) && pto_and_holiday_overlaps(pto))
        end
      end

    end


    private

    def get_holiday_users
    	team_permission_level = @holiday.team_permission_level.compact
      location_permission_level = @holiday.location_permission_level.compact
      status_permission_level = @holiday.status_permission_level.compact

      users = @company.users.where(state: 'active')
      users = users.where(location: location_permission_level) if  location_permission_level.present? &&  location_permission_level[0] != "all"
      users = users.where(team: team_permission_level) if team_permission_level.present? && team_permission_level[0] != "all"
      if status_permission_level.present? && status_permission_level[0] != 'all'
        users = users.joins(:custom_field_values => [custom_field_option: :custom_field]).where("custom_fields.company_id = ? AND custom_fields.field_type = ? AND custom_field_options.option IN (?)", @company.id, 13, status_permission_level)
      end
      users
    end

    def update_pto_request_balance pto
      new_balance = pto.get_balance_used
      pto.update_column(:balance_hours, new_balance) if pto.balance_hours != new_balance
    end

    def holiday_is_not_working_day? pto
      !pto.pto_policy.working_days.include?('Holiday')
    end

    def pto_and_holiday_overlaps pto
      (@holiday.begin_date..@holiday.end_date).overlaps? (pto.begin_date..pto.end_date)
    end
  end
end
