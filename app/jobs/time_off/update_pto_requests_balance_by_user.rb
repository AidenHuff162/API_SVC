module TimeOff
  class UpdatePtoRequestsBalanceByUser
		include Sidekiq::Worker
    sidekiq_options queue: :pto_activities

    def perform(user_id)
      user = User.find_by(id: user_id)
      update_user_pto_balance_by_holiday(user.company, user) if user.present?
    end

    private

    def update_user_pto_balance_by_holiday company, user
      get_user_holidays(company, user).each do |holiday|
        if holiday.multiple_dates.blank? || (holiday.begin_date == holiday.end_date)
          date = holiday.begin_date
          PtoRequest.pto_requests_to_be_updated_by_holiday(company.time.to_date, [user.id]).where('begin_date = ? OR end_date = ?  OR (begin_date < ? AND end_date > ?)', date, date, date, date).find_each do |pto|
            update_pto_request_balance pto if holiday_is_not_working_day? pto
          end
        else
          PtoRequest.pto_requests_to_be_updated_by_holiday(company.time.to_date, [user.id]).find_each do |pto|
              update_pto_request_balance pto if (holiday_is_not_working_day?(pto) && pto_and_holiday_overlaps(pto, holiday))
          end
        end
      end
    end

    def update_pto_request_balance pto
      new_balance = pto.get_balance_used
      pto.update_column(:balance_hours, new_balance) if pto.balance_hours != new_balance
    end

    def holiday_is_not_working_day? pto
      !pto.pto_policy.working_days.include?('Holiday')
    end

    def pto_and_holiday_overlaps pto, holiday
      (holiday.begin_date..holiday.end_date).overlaps? (pto.begin_date..pto.end_date)
    end

    def get_user_holidays company, user
      company.holidays.where("(:status = ANY(status_permission_level) or :status_all = ANY(status_permission_level)) and (:team_all = ANY(team_permission_level) or :team = ANY(team_permission_level)) and (:all_location = ANY(location_permission_level) or :location = ANY(location_permission_level))", status: user.employee_type, status_all: "all", location: user.location_id.to_s, all_location: "all", team: user.team_id.to_s, team_all: "all")
    end
  end
end
