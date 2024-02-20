module UserOffboardManagement
  extend ActiveSupport::Concern

  def terminate_user user
    if user.remove_access_timing == "default" || user.remove_access_timing == "remove_immediately"
      termination_time = (user.termination_date + 1.day).to_time.change({hour: 1, offset: "UTC" })
    elsif user.remove_access_timing == "custom_date"
      termination_time = user.remove_access_date.to_time.change({hour: user.remove_access_time}).asctime.in_time_zone(user.remove_access_timezone)
    end

    ::Users::RemoveAccessJob.perform_async(user.id, termination_time) if termination_time.present?
  end

end