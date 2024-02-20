module OffBoard
  class AssignUserTasksJob
		include Sidekiq::Worker
    sidekiq_options queue: :default, retry: false, backtrace: true

    def perform(user_form_id, user_task_params, user_id)    	
    	offboard_user = User.find_by(id: user_form_id)
    	return unless offboard_user.present? && user_id.present?
    	
    	Interactions::TaskUserConnections::Assign.new(offboard_user, user_task_params, true, false, nil, user_id).perform
    end
  end
end