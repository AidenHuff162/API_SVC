class SendTasksEmailJob
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => false, :backtrace => true

  def perform(user_id, task_ids, is_onboarding = false)
    puts '----------- Send Tasks Email Job Started --------------'
    user = User.find_by_id(user_id)
    Interactions::Activities::Assign.new(user, task_ids, nil, is_onboarding).perform if user
    puts '----------- Send Tasks Email Job Finished --------------'
  end

end
