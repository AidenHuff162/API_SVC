module Users
  class RemoveAccessJob
    include Sidekiq::Worker
    sidekiq_options queue: :remove_access, retry: false, backtrace: true

    def perform(user_id, termination_time)
      user = User.find_by(id: user_id)
      return unless user.present? && termination_time.present?
      begin
        user.offboard_user unless user.departed?
        user.remove_access if user.remove_access_timing == "custom_date" && Time.now.utc > termination_time.to_time.utc && user.reload.remove_access_state == "pending"
        #if user is not offboarding today then do not process the same user again on same day
        if !user.remove_access_timing.eql?('custom_date') && Time.now.utc.to_date < termination_time.to_time.utc.to_date
          user.update_column(:last_offboarding_event_date, Time.now.utc.to_date)
        end
      rescue Exception => e
        LoggingService::GeneralLogging.new.create(user.company, 'User - OffboardUserJob', {result: "Failed to remove access for user_id#{user_id}", error: e.message})
      end
    end
  end
end
