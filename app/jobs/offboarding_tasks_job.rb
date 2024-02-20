class OffboardingTasksJob
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => false, :backtrace => true

  def perform(user_id, task_ids)
  	user = User.find_by(id: user_id)
  	return if user.nil?
  	puts "------------------- Sending OffboardingTasksJob emails to the User #{user.id}"
  	Interactions::Users::OffboardingTasks.new(user, task_ids).perform
  	puts "-------------- Sent OffboardingTasksJob email -----------------"
  end
end
